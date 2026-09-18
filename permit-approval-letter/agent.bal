import ballerina/ai;
import ballerina/workflow;

final ai:ModelProvider permitModel = check ai:getDefaultModelProvider();

# The conditions that attach to each permit class, as the planning office
# publishes them.
#
# + permitClass - The permit class to look up
# + return - The conditions for that class, or an empty array when it is unknown
@ai:AgentTool
isolated function conditionsForClass(string permitClass) returns string[] {
    map<string[]> published = {
        "residential-extension": [
            "Works must start within 12 months of the date of this letter.",
            "Hours of work are limited to 08:00-18:00 on weekdays.",
            "The finished ridge height must not exceed the approved drawings."
        ],
        "change-of-use": [
            "The change of use applies to the ground floor only.",
            "Parking provision must remain at or above the approved count."
        ],
        "demolition": [
            "A demolition method statement must be lodged before works start.",
            "Asbestos survey results must be submitted to the planning office."
        ]
    };
    return published[permitClass] ?: [];
}

# Drafts the letter that decides a permit application. Declared with a
# `resultType`, so a run produces a `LetterDraft` record and the workflow is not
# left parsing prose.
final workflow:DurableAgent letterAgent = check new ({
    systemPrompt: {
        role: string `Building permit correspondence officer`,
        instructions: string `Draft the letter that tells an applicant the decision on their
building permit application. Write to the applicant by name, in plain formal English, and
state the address and what they proposed. Use conditionsForClass to obtain the conditions
published for the permit class and carry them through unchanged. Do not invent conditions,
do not state who approved the application, and do not date the letter: a person signs it
after you draft it.`
    },
    model: permitModel,
    resultType: LetterDraft,
    tools: [conditionsForClass],
    maxIter: 8
});
