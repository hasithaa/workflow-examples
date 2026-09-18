import ballerina/workflow;

# Decides one building permit application and sends the applicant a signed letter.
#
# An officer assesses the plans, the drafting agent writes the letter around what
# they found, and a second officer signs it. The signer is chosen by excluding
# whoever completed the assessment, read back from the assessment task itself, so
# nobody signs off their own assessment. The signature block is taken from the
# sign-off task's completion rather than from anything the letter's author could
# set, so a letter signed by an administrator says so. Posting carries a Retry
# Before Review policy: the postal service is retried, and when those attempts are
# spent a person decides.
#
# + ctx - The workflow context
# + application - The submitted application
# + return - The outcome, with the issued letter when one was sent, or an error
@workflow:Workflow
function permitApprovalWorkflow(workflow:Context ctx, PermitApplication application)
        returns PermitOutcome|error {
    boolean complete = check ctx->callActivity(validateApplication, {"application": application});
    if !complete {
        string _ = check ctx->callActivity(notifyApplicant,
                {"applicationId": application.applicationId,
                    "message": "The application is incomplete and was not assessed."},
                retryPolicy = {maxRetries: 3, retryDelay: 2});
        return {applicationId: application.applicationId, status: "NOT_COMPLIANT"};
    } else {
        AssessmentResult assessment = check ctx->awaitHumanTask("assessPlans",
                {"applicationId": application.applicationId, "applicant": application.applicant,
                    "address": application.address, "permitClass": application.permitClass,
                    "description": application.description},
                userRoles = "permit-officer", administratorRoles = "permit-admin",
                title = string `Assess plans for ${application.applicationId}`,
                description = "Check the submitted plans against the building code and record what you find.",
                timeout = {days: 5});
        if !assessment.compliant {
            string _ = check ctx->callActivity(notifyApplicant,
                    {"applicationId": application.applicationId,
                        "message": string `The plans did not pass assessment: ${assessment.findings}`},
                    retryPolicy = {maxRetries: 3, retryDelay: 2});
            return {applicationId: application.applicationId, status: "NOT_COMPLIANT"};
        } else {
            LetterDraft draft = check ctx->callActivity(draftLetter,
                    {"application": application, "findings": assessment.findings});
            map<json> letterForSigning = {
                "applicationId": application.applicationId,
                "applicant": application.applicant,
                "address": application.address,
                "subject": draft.subject,
                "body": draft.body,
                "conditions": draft.conditions,
                "findings": assessment.findings
            };
            // Whoever assessed the plans is excluded from signing, when the assessment recorded who that was.
            string? assessor = ctx.lastHumanTaskCompletion("assessPlans")?.completedBy;
            SigningDecision decision;
            if assessor is string {
                decision = check ctx->awaitHumanTask("signPermitLetter", letterForSigning,
                        userRoles = "permit-officer", administratorRoles = "permit-admin",
                        excludedUsers = assessor, taskInputType = LetterForSigning,
                        title = string `Sign the permit letter for ${application.applicationId}`,
                        description = "Read the drafted letter, amend its conditions if needed, and sign or refuse it.",
                        timeout = {days: 5});
            } else {
                decision = check ctx->awaitHumanTask("signPermitLetter", letterForSigning,
                        userRoles = "permit-officer", administratorRoles = "permit-admin",
                        taskInputType = LetterForSigning,
                        title = string `Sign the permit letter for ${application.applicationId}`,
                        description = "Read the drafted letter, amend its conditions if needed, and sign or refuse it.",
                        timeout = {days: 5});
            }
            if !decision.approved {
                string _ = check ctx->callActivity(notifyApplicant,
                        {"applicationId": application.applicationId,
                            "message": string `The permit was refused: ${decision.reason}`},
                        retryPolicy = {maxRetries: 3, retryDelay: 2});
                return {applicationId: application.applicationId, status: "REFUSED"};
            } else {
                workflow:HumanTaskCompletion? signOff = ctx.lastHumanTaskCompletion("signPermitLetter");
                string reference = check ctx->callActivity(registerLetter,
                        {"applicationId": application.applicationId});
                PermitLetter letter = {
                    applicationId: application.applicationId,
                    reference,
                    subject: draft.subject,
                    body: draft.body,
                    conditions: decision.amendedConditions ?: draft.conditions,
                    signature: {
                        name: signOff?.completedBy ?: "unrecorded",
                        signedAt: signOff?.completedAt ?: "",
                        asAdministrator: signOff?.completedAs == workflow:ADMINISTRATOR
                    }
                };
                string _ = check ctx->callActivity(postLetter,
                        {"reference": reference, "applicant": application.applicant},
                        retryPolicy = {maxRetries: 2, retryDelay: 2,
                            userRoles: "permit-officer", administratorRoles: "permit-admin",
                            title: string `Letter ${reference} could not be posted`,
                            description: "The postal service kept failing. Retry the send, or fail the application."});
                workflow:ReviewDecisionRecord? deliveryReview = ctx.lastReviewDecision();
                return {
                    applicationId: application.applicationId,
                    status: "GRANTED",
                    letter,
                    deliveryEscalated: deliveryReview is workflow:ReviewDecisionRecord
                };
            }
        }
    }
}
