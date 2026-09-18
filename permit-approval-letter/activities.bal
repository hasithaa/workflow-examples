import ballerina/io;
import ballerina/workflow;

# Drives the drafting agent and waits for the letter it produces. The agent runs
# durably in its own instance; this activity is the workflow's handle on it.
#
# + application - The application to draft a letter for
# + findings - What the assessing officer recorded
# + return - The drafted letter, or an error
@workflow:Activity
function draftLetter(PermitApplication application, string findings) returns LetterDraft|error {
    string instanceId = check letterAgent.run(string `Draft the decision letter for application
${application.applicationId} from ${application.applicant} for ${application.description} at
${application.address}. The permit class is ${application.permitClass}. The assessing officer
found: ${findings}`);
    return letterAgent.waitForResult(instanceId);
}

# Checks the application is complete enough to assess.
#
# + application - The submitted application
# + return - `true` when it can be assessed, or an error
@workflow:Activity
function validateApplication(PermitApplication application) returns boolean|error {
    return application.address.trim().length() > 0 && application.permitClass.trim().length() > 0;
}

# Records the issued letter in the permit register and returns its reference.
#
# + applicationId - The application this letter decides
# + return - The register reference printed on the letter
@workflow:Activity
function registerLetter(string applicationId) returns string|error {
    return string `PL-${applicationId}`;
}

int postAttempts = 0;

# Posts the letter to the applicant. The mock postal service is down for the first
# three attempts, so the Retry Before Review policy spends its retries and then
# raises a review: an officer reruns the send, and that attempt succeeds.
#
# + reference - The letter reference
# + applicant - Who the letter is addressed to
# + return - A delivery receipt, or an error
@workflow:Activity
function postLetter(string reference, string applicant) returns string|error {
    postAttempts += 1;
    if postAttempts <= 3 {
        return error(string `Postal service unavailable while sending ${reference}`);
    }
    io:println(string `[post] Letter ${reference} sent to ${applicant}`);
    return string `POST-${reference}`;
}

# Tells the applicant their plans did not pass assessment.
#
# + applicationId - The application identifier
# + message - The text sent to the applicant
# + return - A notification reference, or an error
@workflow:Activity
function notifyApplicant(string applicationId, string message) returns string|error {
    io:println(string `[notification] ${applicationId}: ${message}`);
    return string `NOTIF-${applicationId}`;
}
