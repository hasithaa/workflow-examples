import ballerina/ai;
import ballerina/http;
import ballerina/io;
import ballerina/workflow;
import ballerinax/metrics.logs as _;

import wso2/icp.runtime.bridge as _;

final ai:ModelProvider expenseModel = check ai:getDefaultModelProvider();

final workflow:DurableAgent expenseAgent = check new ({
    systemPrompt: {
        role: "Expense approval assistant",
        instructions: string `Process expense claims end to end. Validate the claim with
validateClaim first; reject invalid claims with a clear reason. Then check whether the
claim already includes supporting bills. If it does not, call requestBill to notify the
employee and wait — the bills arrive later on the billSubmitted channel. Once you have
the bills, check them with validateBills (there must be at least one bill and the billed
total must match the claimed amount). If the bills check out and the reimbursement is
straightforward, proceed; if anything looks off — mismatched totals, missing bills, or an
unusually large amount — create the approveExpense human task and follow the manager's
decision. Pay the reimbursement with makePayment using the claim's currency, notify the
employee with notifyEmployee, and finish with a one-line summary of the outcome.`
    },
    model: expenseModel,
    activities: [
        validateClaim,
        requestBill,
        validateBills,
        {
            activity: makePayment,
            requiresApproval: true,
            userRoles: "manager",
            retryPolicy: "manager"
        },
        {
            activity: notifyEmployee,
            retryPolicy: {maxRetries: 3, retryDelay: 2}
        }
    ],
    events: [
        {name: "billSubmitted", request: BillSubmission, response: string}
    ],
    humanTasks: [
        {
            name: "approveExpense",
            roles: "manager",
            title: "Approve expense claim",
            description: "Review the claim and bills, then approve or reject the reimbursement."
        }
    ],
    maxIter: 16
});

service /expenses on new http:Listener(9098) {

    # Submits an expense claim to the approval agent.
    #
    # + claim - The expense claim
    # + return - The agent instance identifier used as the claim reference, or an error
    resource function post .(ExpenseClaim claim) returns json|error {
        string instanceId = check expenseAgent.run(claim.toJsonString());
        return {claimId: claim.claimId, instanceId, status: "PROCESSING"};
    }

    # Submits the supporting bills for a claim on the agent's billSubmitted channel and
    # waits for the agent's acknowledgement of that turn.
    #
    # + instanceId - The agent instance identifier returned when the claim was submitted
    # + submission - The bills
    # + return - The agent's reply, or an error
    resource function post [string instanceId]/bills(BillSubmission submission) returns json|error {
        string token = check expenseAgent.sendEvent(instanceId, "billSubmitted", submission);
        string reply = check expenseAgent.waitForEventResult(instanceId, token);
        return {instanceId, reply};
    }

    # Reads the outcome of a claim without blocking: while the agent is waiting on the
    # manager (the approveExpense task or the reimbursement review) the claim reports
    # PENDING_APPROVAL.
    #
    # + instanceId - The agent instance identifier returned when the claim was submitted
    # + return - The agent's summary or the in-progress status, or an error
    resource function get [string instanceId]() returns json|error {
        string|error result = expenseAgent.getResult(instanceId);
        if result is workflow:AgentBusyError {
            return {instanceId, status: "PENDING_APPROVAL"};
        }
        if result is error {
            return result;
        }
        return {instanceId, status: "COMPLETED", summary: result};
    }
}

# Prints the endpoints once the worker and service are up.
#
# + return - An error when startup fails
public function main() returns error? {
    io:println("Expense approval agent listening on http://localhost:9098/expenses");
    io:println("  1. Submit (no bills): curl -X POST localhost:9098/expenses -H 'Content-Type: application/json' -d '{\"claimId\":\"EXP-A1\",\"employee\":\"nimal\",\"amount\":180.50,\"currency\":\"EUR\",\"purpose\":\"Team lunch\"}'");
    io:println("     -> note the instanceId in the response; it is the claim reference below");
    io:println("  2. The agent asks for the bills (requestBill notification in this log)");
    io:println("  3. Submit bills: curl -X POST localhost:9098/expenses/<instanceId>/bills -H 'Content-Type: application/json' -d '{\"bills\":[{\"reference\":\"BILL-9\",\"amount\":180.50}]}'");
    io:println("  4. Decide the approveExpense task in the ICP inbox when the agent creates one (role: manager)");
    io:println("  5. Status: curl localhost:9098/expenses/<instanceId>");
}
