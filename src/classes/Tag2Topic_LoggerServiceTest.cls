/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-file-tags-to-topics
 * License: BSD 3-Clause License
 */
@IsTest
private class Tag2Topic_LoggerServiceTest {

    @IsTest
    static void test_log_exception() {

        ID jobId = AsyncApexJob.SObjectType.getDescribe().getKeyPrefix().rightPad( 15, '0' );

        Exception ex = new System.NullPointerException();
        ex.setMessage( 'Error Message' );

        Test.startTest();

        Tag2Topic_LoggerService.log( jobId, ex );

        Test.stopTest();

        List<Tag2Topic_Log__c> logs = [ SELECT Id, Job_ID__c, Status__c, Summary__c FROM Tag2Topic_Log__c ];
        System.debug( logs );

        System.assertEquals( 1, logs.size() );
        System.assertEquals( jobId, logs[0].Job_ID__c );
        System.assertEquals( 'ERROR', logs[0].Status__c );
        System.assertEquals( ex.getMessage(), logs[0].Summary__c );

    }

    @IsTest
    static void test_log_conversion_results() {

        ID jobId = AsyncApexJob.SObjectType.getDescribe().getKeyPrefix().rightPad( 15, '0' );
        ID fileId = ContentVersion.SObjectType.getDescribe().getKeyPrefix().rightPad( 15, '0' );

        List<Tag2Topic_ConversionService.ConversionResult> conversionResults = new List<Tag2Topic_ConversionService.ConversionResult>();

        Tag2Topic_ConversionService.ConversionResult resultConverted = new Tag2Topic_ConversionService.ConversionResult();
        resultConverted.status = Tag2Topic_ConversionService.ConversionResultStatus.CONVERTED;
        resultConverted.contentVersionId = fileId;
        resultConverted.messages.add( 'converted message' );

        Tag2Topic_ConversionService.ConversionResult resultSkipped = new Tag2Topic_ConversionService.ConversionResult();
        resultSkipped.status = Tag2Topic_ConversionService.ConversionResultStatus.SKIPPED;
        resultSkipped.contentVersionId = fileId;
        resultSkipped.messages.add( 'skipped message' );

        Tag2Topic_ConversionService.ConversionResult resultError = new Tag2Topic_ConversionService.ConversionResult();
        resultError.status = Tag2Topic_ConversionService.ConversionResultStatus.ERROR;
        resultError.contentVersionId = fileId;
        resultError.messages.add( 'error message' );

        conversionResults.add( resultConverted );
        conversionResults.add( resultSkipped );
        conversionResults.add( resultError );

        Test.startTest();

        Tag2Topic_LoggerService.log( jobId, conversionResults );

        Test.stopTest();

        // The 'order by' is important here as it allows us to
        // expect the results in a specific order for our assertions
        // without needing to make multiple queries.
        // Since Status__c is a picklist, then the result will come
        // back in the order the values appear in that field, not necessarily alphabetically.
        List<Tag2Topic_Log__c> logs = [ SELECT Id, Job_ID__c, File_ID__c, Status__c, Summary__c FROM Tag2Topic_Log__c ORDER BY Status__c ];
        System.debug( logs );

        System.assertEquals( conversionResults.size(), logs.size() );

        System.assertEquals( jobId, logs[0].Job_ID__c );
        System.assertEquals( fileId, logs[0].File_ID__c );
        System.assertEquals( 'CONVERTED', logs[0].Status__c );
        System.assertEquals( 'converted message', logs[0].Summary__c );

        System.assertEquals( jobId, logs[1].Job_ID__c );
        System.assertEquals( fileId, logs[1].File_ID__c );
        System.assertEquals( 'SKIPPED', logs[1].Status__c );
        System.assertEquals( 'skipped message', logs[1].Summary__c );

        System.assertEquals( jobId, logs[2].Job_ID__c );
        System.assertEquals( fileId, logs[2].File_ID__c );
        System.assertEquals( 'ERROR', logs[2].Status__c );
        System.assertEquals( 'error message', logs[2].Summary__c );

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