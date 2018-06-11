/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-file-tags-to-topics
 * License: BSD 3-Clause License
 */
@IsTest
private class Tag2Topic_SubmitBatchJobControllerTest {

    @IsTest
    static void test_file_source_options() {

        Test.startTest();

        Tag2Topic_SubmitBatchJobController controller = new Tag2Topic_SubmitBatchJobController();

        List<SelectOption> fileSourceOptions = controller.getFileSourceOptions();
        System.assertEquals( 2, fileSourceOptions.size() );
        System.assertEquals( Tag2Topic_SubmitBatchJobController.OPTION_USER_LIBRARIES, fileSourceOptions[0].getValue() );
        System.assertEquals( Tag2Topic_SubmitBatchJobController.OPTION_USER_SPECIFIED, fileSourceOptions[1].getValue() );

        Test.stopTest();

    }

    @IsTest
    static void test_option_user_libraries() {

        Test.startTest();

        Tag2Topic_SubmitBatchJobController controller = new Tag2Topic_SubmitBatchJobController();

        controller.fileSourceOption = Tag2Topic_SubmitBatchJobController.OPTION_USER_LIBRARIES;
        controller.handleFileSourceOptionChange();

        Set<ID> entityIds = controller.getEntityIds();
        Set<ID> expectedEntityIds = new Map<ID, ContentWorkspace>([ SELECT Id FROM ContentWorkspace ]).keySet();
        System.assert( entityIds.containsAll( expectedEntityIds ) );
        System.assert( expectedEntityIds.containsAll( entityIds ) );

        controller.submit();

        Test.stopTest();

        Boolean hasJobSubmittedMessage = false;
        for ( ApexPages.Message msg : ApexPages.getMessages() ) {
            if ( msg.getSeverity() == ApexPages.Severity.CONFIRM && msg.getSummary().containsIgnoreCase( 'submitted' ) ) {
                hasJobSubmittedMessage = true;
            }
        }
        System.assert( hasJobSubmittedMessage, 'Job was not submitted successfully' );

    }

    @IsTest
    static void test_option_user_specified_record_ids() {

        Test.startTest();

        Tag2Topic_SubmitBatchJobController controller = new Tag2Topic_SubmitBatchJobController();

        controller.fileSourceOption = Tag2Topic_SubmitBatchJobController.OPTION_USER_SPECIFIED;
        controller.handleFileSourceOptionChange();

        controller.entityIdsTextInput = UserInfo.getUserId();

        Set<ID> entityIds = controller.getEntityIds();
        Set<ID> expectedEntityIds = new Set<ID>{ UserInfo.getUserId() };
        System.assert( entityIds.containsAll( expectedEntityIds ) );
        System.assert( expectedEntityIds.containsAll( entityIds ) );

        controller.submit();

        Test.stopTest();

        Boolean hasJobSubmittedMessage = false;
        for ( ApexPages.Message msg : ApexPages.getMessages() ) {
            if ( msg.getSeverity() == ApexPages.Severity.CONFIRM && msg.getSummary().containsIgnoreCase( 'submitted' ) ) {
                hasJobSubmittedMessage = true;
            }
        }
        System.assert( hasJobSubmittedMessage, 'Job was not submitted successfully' );

    }

    @IsTest
    static void test_missing_required_record_ids() {

        Test.startTest();

        Tag2Topic_SubmitBatchJobController controller = new Tag2Topic_SubmitBatchJobController();

        controller.fileSourceOption = Tag2Topic_SubmitBatchJobController.OPTION_USER_SPECIFIED;

        controller.submit();

        Test.stopTest();

        Boolean hasErrorMessage = false;
        for ( ApexPages.Message msg : ApexPages.getMessages() ) {
            if ( msg.getSeverity() == ApexPages.Severity.ERROR && msg.getSummary().containsIgnoreCase( 'Please specify which files to convert' ) ) {
                hasErrorMessage = true;
            }
        }
        System.assert( hasErrorMessage, 'Should display error message' );

    }

    @IsTest
    static void test_parse_unique_values() {

        Test.startTest();

        ID idA = Account.SObjectType.getDescribe().keyPrefix + '001'.rightPad( 12, '0' );
        ID idB = Account.SObjectType.getDescribe().keyPrefix + '002'.rightPad( 12, '0' );
        ID idC = Account.SObjectType.getDescribe().keyPrefix + '003'.rightPad( 12, '0' );

        Set<ID> expectedIds = new Set<ID>{ idA, idB, idC };
        Set<ID> actualIds;

        Tag2Topic_SubmitBatchJobController controller = new Tag2Topic_SubmitBatchJobController();

        List<String> delimiters = new List<String>{
            ' ', ',', ';', ':', '\n', '\r', '\t'
        };

        for ( String delimiter : delimiters ) {

            actualIds = controller.parseUniqueValues( String.join( new List<ID>( expectedIds ), delimiter ) );
            System.assert( expectedIds.containsAll( actualIds ) );
            System.assert( actualIds.containsAll( expectedIds ) );

        }

        Test.stopTest();

    }

    @IsTest
    static void test_exception() {

        Test.startTest();

        Tag2Topic_SubmitBatchJobController controller = new Tag2Topic_SubmitBatchJobController();

        Exception ex = new System.NullPointerException();
        ex.setMessage( 'test error' );
        controller.mockException = ex;

        controller.submit();

        Test.stopTest();

        Boolean hasErrorMessage = false;
        for ( ApexPages.Message msg : ApexPages.getMessages() ) {
            if ( msg.getSeverity() == ApexPages.Severity.ERROR && msg.getSummary().containsIgnoreCase( ex.getMessage() ) ) {
                hasErrorMessage = true;
            }
        }
        System.assert( hasErrorMessage, 'Should display error message' );

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