import ballerina/http;
import ballerina/io;
import ballerina/workflow;
import ballerina/workflow.management;
import wso2/icp.runtime.bridge as _;

service /permits on new http:Listener(9099) {

    # Lodges an application and starts the permit workflow for it.
    #
    # + application - The submitted application
    # + return - The application and workflow instance identifiers, or an error
    resource function post applications(PermitApplication application) returns json|error {
        string workflowId = check workflow:run(permitApprovalWorkflow, application);
        return {applicationId: application.applicationId, workflowId, status: "LODGED"};
    }

    # Reads the outcome of a lodged application. While the assessment or the
    # sign-off is still outstanding the application reports IN_REVIEW.
    #
    # + workflowId - The workflow identifier returned when it was lodged
    # + return - The outcome, or the in-review status, or an error
    resource function get applications/[string workflowId]() returns json|error {
        management:WorkflowExecutionInfo info = check management:getWorkflowInfo(workflowId);
        if info.status == "RUNNING" {
            return {workflowId, status: "IN_REVIEW"};
        }
        anydata outcome = check workflow:getWorkflowResult(workflowId, 30);
        return {workflowId, outcome: check outcome.cloneWithType(json)};
    }
}

# Prints the endpoints once the worker and service are up.
#
# + return - An error when startup fails
public function main() returns error? {
    io:println("Permit approval letters listening on http://localhost:9099/permits");
    io:println("  1. Lodge:   curl -X POST localhost:9099/permits/applications -H 'Content-Type: application/json' -d '{\"applicationId\":\"BP-1\",\"applicant\":\"Rivera Builders\",\"address\":\"14 Mill Lane\",\"permitClass\":\"residential-extension\",\"description\":\"a single-storey rear extension\"}'");
    io:println("     -> note the workflowId in the response; it identifies the application below");
    io:println("  2. Decide the assessPlans task in the ICP inbox (role: permit-officer)");
    io:println("  3. Sign the signPermitLetter task as a DIFFERENT permit-officer");
    io:println("  4. Outcome: curl localhost:9099/permits/applications/<workflowId>");
}
