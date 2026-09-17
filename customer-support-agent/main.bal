import ballerina/ai;
import ballerina/http;
import ballerina/io;
import ballerina/workflow;

final ai:ModelProvider supportModel = check ai:getDefaultModelProvider();

# An order line the support agent can look up.
#
# + orderId - The order identifier
# + status - Fulfilment status
# + amount - Order total
public type OrderInfo record {|
    string orderId;
    string status;
    decimal amount;
|};

# Looks an order up in the order-management system.
#
# + orderId - The order identifier
# + return - The order details, or an error
@workflow:Activity
function lookupOrder(string orderId) returns OrderInfo|error {
    return {orderId, status: "DELIVERED", amount: 129.90d};
}

# Refunds an order in the payment system. Declared with an `approvalPolicy`, so
# every call is gated by a review a support lead has to approve first.
#
# + orderId - The order to refund
# + amount - Amount to refund
# + return - The refund reference, or an error
@workflow:Activity
function issueRefund(string orderId, decimal amount) returns string|error {
    return string `REF-${orderId}`;
}

# Answers common policy questions from the knowledge base.
#
# + topic - The topic to look up (e.g. "returns", "warranty")
# + return - The policy text, or an error
@ai:AgentTool
isolated function policyLookup(string topic) returns string|error {
    map<string> kb = {
        "returns": "Items can be returned within 30 days of delivery.",
        "warranty": "All electronics carry a 12-month manufacturer warranty.",
        "shipping": "Standard shipping takes 3-5 working days."
    };
    return kb[topic.toLowerAscii()] ?: "No policy found for that topic.";
}

final workflow:DurableAgent supportAgent = check new ({
    systemPrompt: {
        role: string `Customer support agent`,
        instructions: string `Help customers with orders, refunds and policy questions.
Use lookupOrder before discussing an order. Refunds require approval — use the
issueRefund tool and tell the customer approval is pending. For anything you
cannot resolve, create the escalation human task.`
    },
    model: supportModel,
    activities: [
        lookupOrder,
        {activity: issueRefund, approvalPolicy: {userRoles: "support-lead"}}
    ],
    tools: [policyLookup],
    events: {
        customerMessage: {request: string, response: string, cardinality: workflow:MULTI_EVENT}
    },
    humanTasks: {
        escalation: {
            userRoles: "support-lead",
            title: "Escalated support case",
            description: "The agent could not resolve the customer's issue on its own."
        }
    },
    maxIter: 12
});

map<string> caseInstances = {};

service /support on new http:Listener(9095) {

    # Opens a support case: starts a durable agent instance for the customer.
    #
    # + request - The case number and the customer's opening message
    # + return - The case and agent instance identifiers, or an error
    resource function post cases(record {|string caseNo; string message;|} request)
            returns json|error {
        string instanceId = check supportAgent.run(request.message);

        caseInstances[request.caseNo] = instanceId;
        return {caseNo: request.caseNo, instanceId, status: "OPEN"};
    }

    # Sends a follow-up customer message on the case's conversation channel and
    # waits (durably, crash-resumable) for the agent's reply to that turn.
    #
    # + caseNo - The case number
    # + message - The customer's message
    # + return - The agent's reply, or an error
    resource function post cases/[string caseNo]/messages(record {|string message;|} message)
            returns json|error {
        string? instanceId = caseInstances[caseNo];
        if instanceId is () {
            return error(string `unknown case: ${caseNo}`);
        }
        string token = check supportAgent.sendData(instanceId, "customerMessage", message.message);
        string reply = check supportAgent.waitForDataResult(instanceId, token);
        return {caseNo, reply};
    }

    # Reads the case outcome without blocking: while the agent is still working
    # (e.g. suspended on the refund approval) the case reports IN_PROGRESS.
    #
    # + caseNo - The case number
    # + return - The final summary or the in-progress status, or an error
    resource function get cases/[string caseNo]() returns json|error {
        string? instanceId = caseInstances[caseNo];
        if instanceId is () {
            return error(string `unknown case: ${caseNo}`);
        }
        string|error result = supportAgent.getResult(instanceId);
        if result is workflow:AgentBusyError {
            return {caseNo, status: "IN_PROGRESS"};
        }
        if result is error {
            return result;
        }
        return {caseNo, status: "RESOLVED", summary: result};
    }
}

# Prints the endpoints once the worker and service are up.
#
# + return - An error when startup fails
public function main() returns error? {
    io:println("Customer support agent listening on http://localhost:9095/support");
    io:println("  1. Open a case:   curl -X POST localhost:9095/support/cases -H 'Content-Type: application/json' -d '{\"caseNo\":\"CS-1\",\"message\":\"Where is my order ORD-77?\"}'");
    io:println("  2. Follow up:     curl -X POST localhost:9095/support/cases/CS-1/messages -H 'Content-Type: application/json' -d '{\"message\":\"Please refund it.\"}'");
    io:println("  3. Check status:  curl localhost:9095/support/cases/CS-1");
}
