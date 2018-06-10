/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-file-tags-to-topics
 * License: BSD 3-Clause License
 */
@IsTest
private class Tag2Topic_FilesBatchableTest {

    @IsTest
    static void test_batch_all_libraries() {

        Profile adminProfile = [ SELECT id FROM Profile WHERE name = 'System Administrator' ];
        Profile stdUserProfile = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User adminUser, stdUser;

        ContentWorkspace library;
        ContentVersion fileA, fileB, fileC, fileD;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            adminUser = Tag2Topic_Utils.newUser( adminProfile.Id, 'Alpha', 'User 1', 'user_1@example.com' );

            stdUser = Tag2Topic_Utils.newUser( stdUserProfile.Id, 'Beta', 'User 2', 'user_2@example.com' );

            insert new User[] { adminUser, stdUser };

            PermissionSet tag2topicPermSet = [ SELECT Id FROM PermissionSet WHERE Name = 'Convert_File_Tags_to_Topics' ];

            PermissionSetAssignment adminUserPSA = new PermissionSetAssignment(
                AssigneeId = adminUser.Id,
                PermissionSetId = tag2topicPermSet.Id
            );

            insert adminUserPSA;

        }

        System.runAs( adminUser ) {

            library = new ContentWorkspace(
                Name = 'Test Library ' + System.currentTimeMillis(),
                ShouldAddCreatorMembership = true
            );

            insert library;

            ContentWorkspacePermission permission = new ContentWorkspacePermission(
                Name = 'Test Library Permission ' + System.currentTimeMillis(),
                PermissionsAddContent = true,
                PermissionsTagContent = true
            );

            insert permission;

            ContentWorkspaceMember stdUserMember = new ContentWorkspaceMember(
                MemberId = stdUser.Id,
                ContentWorkspaceId = library.Id,
                ContentWorkspacePermissionId = permission.Id
            );

            insert stdUserMember;

        }

        System.runAs( stdUser ) {

            // FileA should be skipped because no tags
            fileA = new ContentVersion(
                Title = 'FileA',
                PathOnClient = '/FileA.txt',
                TagCsv = null,
                VersionData = Blob.valueOf( 'FileA' ),
                FirstPublishLocationId = library.Id
            );

            // FileB should convert
            // trailhead is existing topic, astro is new topic, fun is new topic
            fileB = new ContentVersion(
                Title = 'FileB',
                PathOnClient = '/FileB.txt',
                TagCsv = 'trailhead, astro, fun',
                VersionData = Blob.valueOf( 'FileB' ),
                FirstPublishLocationId = library.Id
            );

            // FileC should convert
            // trailhead is existing topic, codey is new topic, fun should be detected as existing topic from FileB
            fileC = new ContentVersion(
                Title = 'FileC',
                PathOnClient = '/FileC.txt',
                TagCsv = 'trailhead, codey, fun',
                VersionData = Blob.valueOf( 'FileC' ),
                FirstPublishLocationId = library.Id
            );

            // FileD should fail because its tag is larger than max allowed topic name
            fileD = new ContentVersion(
                Title = 'FileD',
                PathOnClient = '/FileD.txt',
                TagCsv = 'x'.repeat( Topic.Name.getDescribe().getLength() + 1 ),
                VersionData = Blob.valueOf( 'FileD' ),
                FirstPublishLocationId = library.Id
            );

            insert new List<ContentVersion>{ fileA, fileB, fileC, fileD };

        }

        System.runAs( adminUser ) {

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
            ]);
            System.assertEquals( 4, filesMap.size() );

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

            Set<ID> entityIds = new Set<ID> { library.Id };

            Database.executeBatch( new Tag2Topic_FilesBatchable( entityIds ) );

            Test.stopTest();

            Integer countConverted = 0;
            Integer countSkipped = 0;
            Integer countError = 0;

            for ( Tag2Topic_Log__c log : [ SELECT Id, Status__c FROM Tag2Topic_Log__c ] ) {

                System.debug( log );

                if ( log.Status__c == 'CONVERTED' ) {
                   countConverted++;
                }

                if ( log.Status__c == 'SKIPPED' ) {
                    countSkipped++;
                }

                if ( log.Status__c == 'ERROR' ) {
                    countError++;
                }

    //            switch on log.Status__c {
    //                when 'CONVERTED' {
    //                    countConverted++;
    //                }
    //                when 'SKIPPED' {
    //                    countSkipped++;
    //                }
    //                when 'ERROR' {
    //                    countError++;
    //                }
    //            }

            }

            System.assertEquals( 1, countError );
            // batch start query filters out files without tags,
            // so the conversion service should not actually have to skip any files
            System.assertEquals( 0, countSkipped );
            System.assertEquals( 2, countConverted );

            System.assertEquals( 0, [ SELECT COUNT() FROM TopicAssignment WHERE EntityId IN ( :fileA.ContentDocumentId, :fileD.ContentDocumentId ) ] );

            Tag2Topic_Utils.assertFileAssignedTopicForEachTag( fileB.ContentDocumentId, Tag2Topic_Utils.split( fileB.TagCsv, ',' ) );
            Tag2Topic_Utils.assertFileAssignedTopicForEachTag( fileC.ContentDocumentId, Tag2Topic_Utils.split( fileC.TagCsv, ',' ) );

        }

    }

    @IsTest
    static void test_batch_specific_entities() {

        Account acctA = new Account(
            Name = 'Account A'
        );

        Account acctB = new Account(
            Name = 'Account B'
        );

        insert new Account[] { acctA, acctB };

        ContentVersion fileA = new ContentVersion(
            Title = 'FileA',
            PathOnClient = '/FileA.txt',
            TagCsv = 'trailhead, astro',
            VersionData = Blob.valueOf( 'FileA' ),
            FirstPublishLocationId = acctA.Id
        );

        ContentVersion fileB = new ContentVersion(
            Title = 'FileB',
            PathOnClient = '/FileB.txt',
            TagCsv = 'trailhead, codey',
            VersionData = Blob.valueOf( 'FileB' )
        );

        insert new ContentVersion[] { fileA, fileB };

        fileA = [ SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :fileA.Id ];
        fileB = [ SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :fileB.Id ];

        Test.startTest();

        Set<ID> entityIds = new Set<ID> { acctA.Id }; // only convert acctA's files, not acctB's

        Database.executeBatch( new Tag2Topic_FilesBatchable( entityIds ) );

        Test.stopTest();

        System.assertEquals( 2, [ SELECT COUNT() FROM TopicAssignment WHERE EntityId = :fileA.ContentDocumentId ] );
        System.assertEquals( 0, [ SELECT COUNT() FROM TopicAssignment WHERE EntityId = :fileB.ContentDocumentId ] );

    }

    @IsTest
    static void test_batch_exception() {

        Account acctA = new Account(
            Name = 'Account A'
        );

        insert acctA;

        ContentVersion fileA = new ContentVersion(
            Title = 'FileA',
            PathOnClient = '/FileA.txt',
            TagCsv = 'trailhead, astro',
            VersionData = Blob.valueOf( 'FileA' ),
            FirstPublishLocationId = acctA.Id
        );

        insert fileA;

        fileA = [ SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :fileA.Id ];

        Test.startTest();

        Exception ex = new System.NullPointerException();
        ex.setMessage( 'exception message' );

        Set<ID> entityIds = new Set<ID> { acctA.Id };

        Tag2Topic_FilesBatchable job = new Tag2Topic_FilesBatchable( entityIds );
        job.mockException = ex;

        ID jobId = Database.executeBatch( job );

        Test.stopTest();

        System.assertEquals( 0, [ SELECT COUNT() FROM TopicAssignment ] );

        Tag2Topic_Log__c errorLog = [ SELECT Id, Job_ID__c, Status__c, Summary__c FROM Tag2Topic_Log__c ];
        System.assertEquals( jobId, errorLog.Job_ID__c );
        System.assertEquals( 'ERROR', errorLog.Status__c );
        System.assertEquals( ex.getMessage(), errorLog.Summary__c );

    }

}
/*
BSD 3-Clause License

Copyright (c) 2018, Doug Ayers, douglascayers.com
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/