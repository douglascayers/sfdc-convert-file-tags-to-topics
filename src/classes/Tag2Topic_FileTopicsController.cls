/**
 * Just a placeholder until this org is upgraded to Summer '18
 * and the related Visualforce page can be replaced with the Topics Lightning Component.
 */
public with sharing class Tag2Topic_FileTopicsController {

    @AuraEnabled
    public static List<TopicAssignment> getTopicAssignments( ID entityId ) {
        return [
            SELECT
                Id,
                TopicId,
                Topic.Name
            FROM
                TopicAssignment
            WHERE
                EntityId = :entityId
            ORDER BY
                Topic.Name
        ];
    }

}