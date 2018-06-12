@IsTest
private class Tag2Topic_ConversionServiceTest {

    @IsTest
    static void test_conversion_service() {

        /*
         * Note, Topic and PushTopic among other objects that have unique indexes on them and
         * will throw duplicate value error if test data that you create would duplicate an actual value in the org.
         * SeeAllData annotation and 'without sharing' have no effect on whether your code will or will not see the org data.
         * https://salesforce.stackexchange.com/questions/12258/pushtopic-test-duplicate-name-bug
         * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_data_access.htm
         */

        String tagName1 = 'topic1' + System.currentTimeMillis(); // fileB, fileC
        String tagName2 = 'topic2' + System.currentTimeMillis(); // fileB, fileC
        String tagName3 = 'topic3' + System.currentTimeMillis(); // fileB
        String tagName4 = 'topic4' + System.currentTimeMillis(); // fileC
        String tagName5 = ( 'topic5' + System.currentTimeMillis() ).rightPad( Topic.Name.getDescribe().getLength() + 1, 'x' ); // fileD

        // FileA should be skipped because no tags
        ContentVersion fileA = new ContentVersion(
            Title = 'FileA',
            PathOnClient = '/FileA.txt',
            TagCsv = null,
            VersionData = Blob.valueOf( 'FileA' )
        );

        // FileB should convert
        // trailhead is existing topic, astro is new topic, fun is new topic
        ContentVersion fileB = new ContentVersion(
            Title = 'FileB',
            PathOnClient = '/FileB.txt',
            TagCsv = String.join( new String[] { tagName1, tagName2, tagName3 }, ',' ),
            VersionData = Blob.valueOf( 'FileB' )
        );

        // FileC should convert
        // trailhead is existing topic, codey is new topic, fun should be detected as existing topic from FileB
        ContentVersion fileC = new ContentVersion(
            Title = 'FileC',
            PathOnClient = '/FileC.txt',
            TagCsv = String.join( new String[] { tagName1, tagName2, tagName4 }, ',' ),
            VersionData = Blob.valueOf( 'FileC' )
        );

        // FileD should fail because its tag is larger than max allowed topic name
        ContentVersion fileD = new ContentVersion(
            Title = 'FileD',
            PathOnClient = '/FileD.txt',
            TagCsv = tagName5,
            VersionData = Blob.valueOf( 'FileD' )
        );

        List<ContentVersion> files = new List<ContentVersion>{ fileA, fileB, fileC, fileD };

        insert files;

        // conversion service expects these three fields
        // also, have to re-query content version to learn its
        // auto-assigned content document id on insert
        Map<ID, ContentVersion> filesMap = new Map<ID, ContentVersion>([
            SELECT
                Id,
                ContentDocumentId,
                TagCsv
            FROM
                ContentVersion
            WHERE
                Id IN :files
        ]);
        files = filesMap.values();

        // Ensure variable references to files A,B,C,D
        // also have their generated content document id
        // as we make reference to them in test assertions.
        fileA = filesMap.get( fileA.Id );
        fileB = filesMap.get( fileB.Id );
        fileC = filesMap.get( fileC.Id );
        fileD = filesMap.get( fileD.Id );

        // assign a topic to only of the files with tags
        // to test the service logic to detect assigned topics
        Topic topic1 = new Topic(
            Name = tagName1
        );

        insert topic1;

        TopicAssignment fileB_topicTrailhead = new TopicAssignment(
            EntityId = fileB.ContentDocumentId,
            TopicId = topic1.Id
        );

        insert fileB_topicTrailhead;

        Test.startTest();

        Tag2Topic_ConversionService service = new Tag2Topic_ConversionService();

        List<Tag2Topic_ConversionService.ConversionResult> conversionResults = service.convertTagsToTopics( files );

        Test.stopTest();

        Integer countConverted = 0;
        Integer countSkipped = 0;
        Integer countError = 0;

        for ( Tag2Topic_ConversionService.ConversionResult conversionResult : conversionResults ) {

            System.debug( conversionResult );

            switch on conversionResult.status {
                when CONVERTED {
                    countConverted++;
                }
                when SKIPPED {
                    countSkipped++;
                }
                when ERROR {
                    countError++;
                }
            }

        }

        System.assertEquals( files.size(), conversionResults.size() );
        System.assertEquals( 1, countError );
        System.assertEquals( 1, countSkipped );
        System.assertEquals( 2, countConverted );

        System.assertEquals( 0, [ SELECT COUNT() FROM TopicAssignment WHERE EntityId IN ( :fileA.ContentDocumentId, :fileD.ContentDocumentId ) ] );

        Tag2Topic_Utils.assertFileAssignedTopicForEachTag( fileB.ContentDocumentId, Tag2Topic_Utils.split( fileB.TagCsv, ',' ) );
        Tag2Topic_Utils.assertFileAssignedTopicForEachTag( fileC.ContentDocumentId, Tag2Topic_Utils.split( fileC.TagCsv, ',' ) );

    }

}