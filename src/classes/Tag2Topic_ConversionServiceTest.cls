@IsTest
private class Tag2Topic_ConversionServiceTest {

    @IsTest
    static void test_conversion_service() {

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
            TagCsv = 'trailhead, astro, fun',
            VersionData = Blob.valueOf( 'FileB' )
        );

        // FileC should convert
        // trailhead is existing topic, codey is new topic, fun should be detected as existing topic from FileB
        ContentVersion fileC = new ContentVersion(
            Title = 'FileC',
            PathOnClient = '/FileC.txt',
            TagCsv = 'trailhead, codey, fun',
            VersionData = Blob.valueOf( 'FileC' )
        );

        // FileD should fail because its tag is larger than max allowed topic name
        ContentVersion fileD = new ContentVersion(
            Title = 'FileD',
            PathOnClient = '/FileD.txt',
            TagCsv = 'x'.repeat( Topic.Name.getDescribe().getLength() + 1 ),
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

        // ensure variable references to files A,B,C,D
        // also have their generated content document id
        // as we make reference to them in test assertions
        fileA = filesMap.get( fileA.Id );
        fileB = filesMap.get( fileB.Id );
        fileC = filesMap.get( fileC.Id );
        fileD = filesMap.get( fileD.Id );

        // assign a topic to only of the files with tags
        // to test the service logic to detect assigned topics
        Topic topicTrailhead = new Topic(
            Name = 'Trailhead'
        );

        insert topicTrailhead;

        TopicAssignment fileB_topicTrailhead = new TopicAssignment(
            EntityId = fileB.ContentDocumentId,
            TopicId = topicTrailhead.Id
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

        assertFileAssignedTopicForEachTag( fileB );
        assertFileAssignedTopicForEachTag( fileC );

    }

    // --------------------------------------------

    private static void assertFileAssignedTopicForEachTag( ContentVersion file ) {

        List<String> tagNames = Tag2Topic_Utils.split( file.TagCsv, ',' );

        List<TopicAssignment> assignments = [ SELECT Id, EntityId, TopicId, Topic.Name FROM TopicAssignment WHERE EntityId = :file.ContentDocumentId ];

        System.assertEquals( tagNames.size(), assignments.size() );

        for ( String tagName : tagNames ) {
            Boolean topicFound = false;
            for ( TopicAssignment assignment : assignments ) {
                if ( tagName.equalsIgnoreCase( assignment.Topic.Name ) ) {
                    topicFound = true;
                    break;
                }
            }
            System.assert( topicFound, 'No topic assignment found for tag: ' + tagName );
        }


    }

}