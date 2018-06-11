/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-file-tags-to-topics
 * License: BSD 3-Clause License
 */
public with sharing class Tag2Topic_SubmitBatchJobController {

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------

    /**
     * Visualforce can't convert string to enums so using strings instead.
     */
    public static final String OPTION_USER_LIBRARIES = 'USER_LIBRARIES';
    public static final String OPTION_USER_SPECIFIED = 'USER_SPECIFIED';

    public String fileSourceOption { get; set; }

    public String entityIdsTextInput { get; set; }

    public Integer batchSize { get; set; }

    public Tag2Topic_SubmitBatchJobController() {
        this.batchSize = 200;
    }

    // ----------------------------------------------------------

    /**
     * To be called from Visualforce page to submit the batch job.
     */
    public void submit() {

        SavePoint sp = Database.setSavePoint();

        try {

            if ( Test.isRunningTest() ) {
                if ( this.mockException != null ) {
                    throw this.mockException;
                }
            }

            Set<ID> entityIds = getEntityIds();

            if ( entityIds == null || entityIds.isEmpty() ) {

                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'Please specify which files to convert.' ) );

            } else {

                ID jobId = Database.executeBatch( new Tag2Topic_FilesBatchable( entityIds ), this.batchSize );

                // Display the 15 character job id to match exactly what the user can search for on the Apex Jobs page in Setup menu
                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.CONFIRM, 'Batch job submitted: ' + String.valueOf( jobId ).left( 15 ) ) );

            }

        } catch ( Exception e ) {

            Database.rollback( sp );

            System.debug( LoggingLevel.ERROR, e );

            ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, e.getMessage(), e.getStackTraceString() ) );

        }

    }

    // ----------------------------------------------------------

    public List<SelectOption> getFileSourceOptions() {

        List<SelectOption> options = new List<SelectOption>();

        options.add( new SelectOption( OPTION_USER_LIBRARIES, 'Files shared to libraries where you are a member' ) );
        options.add( new SelectOption( OPTION_USER_SPECIFIED, 'Files shared to record ids that you specify' ) );

        return options;
    }

    public void handleFileSourceOptionChange() {

        System.debug( 'file option changed: ' + this.fileSourceOption );

    }

    // ----------------------------------------------------------

    @TestVisible
    private Set<ID> getEntityIds() {

        Set<ID> entityIds = new Set<ID>();

        if ( this.fileSourceOption == OPTION_USER_LIBRARIES ) {

            entityIds = new Map<ID, ContentWorkspace>([ SELECT Id FROM ContentWorkspace ]).keySet();

        } else if ( this.fileSourceOption == OPTION_USER_SPECIFIED ) {

            entityIds = parseUniqueValues( this.entityIdsTextInput );

        }

        return entityIds;
    }

    /**
     * Splits the text by delimiter and returns the unique values.
     *
     * The text can contain these delimiters: commas, semicolons, colons, \n, \r, \t, and spaces.
     *
     * Designed for identifying the unique set of record ids the user provides in a textarea input field.
     */
    @TestVisible
    private Set<ID> parseUniqueValues( String text ) {

        System.debug( 'parsing unique values: ' + text );

        Set<ID> values = new Set<ID>();

        if ( String.isNotBlank( text ) ) {

            text = text.replaceAll( '[ ,;:\n\r\t]+', ',' );

            System.debug( 'cleaned text: ' + text );

            for ( String value : text.split( ',' ) ) {
                values.add( ID.valueOf( value.trim() ) );
            }

        }

        System.debug( 'returning unique values: ' + values );

        return values;
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