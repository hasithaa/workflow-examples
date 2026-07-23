import ballerina/workflow;

# KYC checks for an applicant, run as a child workflow.
#
# + ctx - The workflow context
# + applicant - The applicant to verify
# + return - The KYC result, or an error
@workflow:Workflow
function kycWorkflow(workflow:Context ctx, Applicant applicant) returns KycResult|error {
    boolean identityVerified = check ctx->callActivity(verifyIdentity, {"nic": applicant.nic});
    boolean onSanctionsList = check ctx->callActivity(checkSanctionsList, {"nic": applicant.nic});
    return {nic: applicant.nic, identityVerified, onSanctionsList};
}

# Credit scoring for an application, run as a child workflow.
#
# + ctx - The workflow context
# + application - The application to score
# + return - The credit score, or an error
@workflow:Workflow
function creditScoreWorkflow(workflow:Context ctx, LoanApplication application) returns CreditScore|error {
    int score = check ctx->callActivity(fetchBureauScore, {"nic": application.applicant.nic});
    return {nic: application.applicant.nic, score, openDefaults: 0};
}

# Disburses an approved loan. The transfer only happens after treasury releases
# the funds — the workflow durably suspends on the `fundsRelease` data event
# (sent by the parent with `sendDataToChildWorkflow`) for as long as that takes.
#
# + ctx - The workflow context
# + request - The disbursement request
# + dataEvents - Futures for the data events this workflow waits on
# + return - The disbursement record, or an error
@workflow:Workflow
function disbursementWorkflow(workflow:Context ctx, DisbursementRequest request,
        record {|future<FundsRelease> fundsRelease;|} dataEvents) returns Disbursement|error {
    FundsRelease release = check wait dataEvents.fundsRelease;

    string reference = check ctx->callActivity(transferFunds,
            {"accountNo": request.accountNo, "amount": request.amount}, retryPolicy = "manager");
    return {applicationId: request.applicationId, reference, batchNo: release.batchNo};
}

# Sends the decision notification, run synchronously as a child workflow.
#
# + ctx - The workflow context
# + decision - The decision to notify
# + return - The delivery reference, or an error
@workflow:Workflow
function notificationWorkflow(workflow:Context ctx, LoanDecision decision) returns string|error {
    string message = decision.approved
        ? string `Your loan ${decision.applicationId} was approved.`
        : string `Your loan ${decision.applicationId} was declined: ${decision.reason}`;
    return ctx->callActivity(notifyApplicant,
            {"applicationId": decision.applicationId, "message": message});
}

# The end-to-end loan application process.
#
# + ctx - The workflow context
# + application - The submitted application
# + return - The final decision, or an error
@workflow:Workflow
function loanApplicationWorkflow(workflow:Context ctx, LoanApplication application)
        returns LoanDecision|error {
    boolean valid = check ctx->callActivity(validateApplication, {"application": application});
    if !valid {
        return {applicationId: application.applicationId, approved: false, reason: "Invalid application"};
    } else {
        string kycId = check ctx->runChildWorkflow(kycWorkflow, input = application.applicant);
        string scoreId = check ctx->runChildWorkflow(creditScoreWorkflow, input = application);
        KycResult kyc = check ctx->waitForChildWorkflow(kycId);
        CreditScore credit = check ctx->waitForChildWorkflow(scoreId);

        LoanDecision decision;
        if !kyc.identityVerified || kyc.onSanctionsList {
            decision = {applicationId: application.applicationId, approved: false, reason: "KYC failed"};
        } else if credit.score < 600 || credit.openDefaults > 0 {
            decision = {
                applicationId: application.applicationId,
                approved: false,
                reason: string `Credit score ${credit.score} below threshold`
            };
        } else {
            string disbursementId = check ctx->runChildWorkflow(disbursementWorkflow,
                input = <DisbursementRequest>{
                applicationId: application.applicationId,
                accountNo: string `SAV-${application.applicant.nic}`,
                amount: application.amount
            });
            check ctx->sendDataToChildWorkflow(disbursementId, "fundsRelease",
                <FundsRelease>{batchNo: "BATCH-42", valueDate: "2026-07-22"});
            Disbursement disbursement = check ctx->waitForChildWorkflow(disbursementId);

            decision = {
                applicationId: application.applicationId,
                approved: true,
                reason: "Approved",
                disbursementRef: disbursement.reference
            };
        }

        string _ = check ctx->callWorkflow(notificationWorkflow, input = decision);
        return decision;
    }

}
