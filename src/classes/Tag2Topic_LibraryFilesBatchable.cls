/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-file-tags-to-topics
 * License: BSD 3-Clause License
 */
public without sharing class Tag2Topic_LibraryFilesBatchable implements Database.Batchable<ContentDocumentLink> {

    @TestVisible
    private List<Tag2Topic_ConversionService.ConversionResult> mockResults { get; set; }

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------

    private Set<ID> linkedEntityIds { get; set; }

    /**
     * Default Constructor
     *
     * Files shared to libraries will have their
     * tags converted and assigned as topics.
     */
    public Tag2Topic_LibraryFilesBatchable() {
        this( null );
    }

    /**
     * Constructor
     *
     * @param linkedEntityIds
     *      To scope which files get converted.
     *      Only files shared to these entities will have their
     *      tags converted and assigned as topics.
     */
    public Tag2Topic_LibraryFilesBatchable( Set<ID> linkedEntityIds ) {
        this.linkedEntityIds = linkedEntityIds;
    }

    // ----------------------------------------------------------

    // Known Issue have to use Iterable instead of Database.QueryLocator:
    // https://success.salesforce.com/issues_view?id=a1p3A0000018COxQAM
    public Iterable<ContentDocumentLink> start( Database.BatchableContext context ) {

        System.debug( 'Tag2Topic_LibraryFilesBatchable.start: ' + context );

        // In order to query for files not explicitly shared to a user,
        // then we must go through content document link and find them
        // shared to records that the user has access to.

        if ( this.linkedEntityIds == null || this.linkedEntityIds.isEmpty() ) {

            return [
                SELECT
                    Id,
                    ContentDocumentId,
                    ContentDocument.LatestPublishedVersion.ContentDocumentId,
                    ContentDocument.LatestPublishedVersion.TagCsv
                FROM
                    ContentDocumentLink
                WHERE
                    LinkedEntityId IN (
                        SELECT Id FROM ContentWorkspace
                    )
                    AND
                    (
                        ContentDocument.LatestPublishedVersion.Have_Converted_Tags_to_Topics__c = null
                        OR
                        ContentDocument.LatestPublishedVersion.Have_Converted_Tags_to_Topics__c = false
                    )
            ];

        } else {

            return [
                SELECT
                    Id,
                    ContentDocumentId,
                    ContentDocument.LatestPublishedVersion.ContentDocumentId,
                    ContentDocument.LatestPublishedVersion.TagCsv
                FROM
                    ContentDocumentLink
                WHERE
                    LinkedEntityId IN :this.linkedEntityIds
                    AND
                    (
                        ContentDocument.LatestPublishedVersion.Have_Converted_Tags_to_Topics__c = null
                        OR
                        ContentDocument.LatestPublishedVersion.Have_Converted_Tags_to_Topics__c = false
                    )
            ];

        }

    }

    public void execute( Database.BatchableContext context, List<ContentDocumentLink> cdls ) {

        System.debug( 'Tag2Topic_LibraryFilesBatchable.execute: ' + context );

        SavePoint sp = Database.setSavePoint();

        try {

            // Because we queried for content document links and not the files directly,
            // then we actually may get the same file reference multiple times, once per
            // every entity the file is shared to. Therefore, we should filter down to
            // the unique files seen in the batch of links given to us.
            Map<ID, ContentVersion> filesMap = new Map<ID, ContentVersion>();

            for ( ContentDocumentLink cdl : cdls ) {

                ContentDocument cd = cdl.ContentDocument;
                ContentVersion cv = cd.LatestPublishedVersion;

                if ( String.isNotBlank( cv.TagCsv ) ) {
                    filesMap.put( cv.Id, cv );
                }

            }

            if ( filesMap.size() > 0 ) {

                Tag2Topic_ConversionService service = new Tag2Topic_ConversionService();

                List<Tag2Topic_ConversionService.ConversionResult> results = service.convertTagsToTopics( filesMap.values() );

                if ( Test.isRunningTest() ) {

                    if ( this.mockException != null ) {
                        throw this.mockException;
                    }

                    if ( this.mockResults != null ) {
                        results = mockResults;
                    }

                }

                Tag2Topic_LoggerService.log( context.getJobId(), results );

            }

        } catch ( Exception e ) {

            Database.rollback( sp );

            Tag2Topic_LoggerService.log( context.getJobId(), e );

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Tag2Topic_LibraryFilesBatchable.finish: ' + context );

        Tag2Topic_LoggerService.sendApexExceptionEmailIfAnyErrorsSince( context.getJobId() );

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