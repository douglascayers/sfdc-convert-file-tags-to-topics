/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-file-tags-to-topics
 * License: BSD 3-Clause License
 */
public without sharing class Tag2Topic_ConversionService {

    /**
     * For each file, inserts TopicAssignment records for each of its tags (ContentVersion.TagCsv).
     * Topics are created as necessary, if do not already exist by the tag names.
     * Topics are assigned as necessary, if they are not already assigned to the file.
     *
     * Returns a list of conversion results indicating whether the topics were assigned
     * or if an error occurred during the conversion process.
     *
     * The topic assignments are saved optimistically (allOrNone=false).
     */
    public List<ConversionResult> convertTagsToTopics( List<ContentVersion> files ) {

        System.debug( 'Tag2Topic_ConversionService.convertTagsToTopics' );

        Map<ID, ConversionResult> contentDocumentIdToConversionResultMap = initConversionResultByContentDocumentIdMap( files );

        List<TopicAssignment> topicsToAssign = getTopicsToAssignForTags( files, contentDocumentIdToConversionResultMap );

        assignTopicsToFiles( topicsToAssign, contentDocumentIdToConversionResultMap );

        // Ensure returned list of results is same order as the files parameter.
        // This is common convention among apex DML operations.
        List<ConversionResult> conversionResults = new List<ConversionResult>();
        for ( ContentVersion file : files ) {
            conversionResults.add( contentDocumentIdToConversionResultMap.get( file.ContentDocumentId ) );
        }

        return conversionResults;
    }

    // --------------------------------------------

    private Map<ID, ConversionResult> initConversionResultByContentDocumentIdMap( List<ContentVersion> files ) {

        Map<ID, ConversionResult> resultMap = new Map<ID, ConversionResult>();

        for ( ContentVersion file : files ) {

            // Assume that the file is skipped to start with because
            // unless a file has a topic to assign, then we won't process the file.
            // In the method to assign topics to files, it may adjust the status/messages.
            ConversionResult result = new ConversionResult();
            result.status = ConversionResultStatus.SKIPPED;
            result.messages.add( String.isBlank( file.TagCsv ) ? 'File is not assigned any tags' : 'All tags are already assigned as topics: ' + file.TagCsv );
            result.contentVersionId = file.Id;
            result.contentDocumentId = file.ContentDocumentId;

            resultMap.put( file.ContentDocumentId, result );

        }

        return resultMap;
    }

    private void assignTopicsToFiles( List<TopicAssignment> topicsToAssign, Map<ID, ConversionResult> contentDocumentIdToConversionResultMap ) {

        Boolean allOrNone = false;

        List<Database.UpsertResult> upsertResults = Database.upsert( topicsToAssign, allOrNone );

        for ( Integer i = 0; i < upsertResults.size(); i++ ) {

            Database.UpsertResult upsertResult = upsertResults[i];

            TopicAssignment topicToAssign = topicsToAssign[i];
            ID contentDocumentId = topicToAssign.EntityId;
            ConversionResult conversionResult = contentDocumentIdToConversionResultMap.get( contentDocumentId );

            // all files initial status is skipped assuming no topics to assign
            // if we do in fact assign topics then we update the status to
            // error or converted and clear any prior messages
            if ( conversionResult.status == ConversionResultStatus.SKIPPED ) {
                conversionResult.status = null;
                conversionResult.messages = new Set<String>();
            }

            if ( !upsertResult.isSuccess() ) {

                for ( Database.Error err : upsertResult.getErrors() ) {
                    conversionResult.messages.add( 'Error assigning topic ' + topicToAssign.Topic.Name + ': ' + err.getMessage() );
                }

                conversionResult.status = ConversionResultStatus.ERROR;

            } else if ( conversionResult.status != ConversionResultStatus.ERROR ) {

                conversionResult.messages.add( 'Assigned topic: ' + topicToAssign.Topic.Name );
                conversionResult.status = ConversionResultStatus.CONVERTED;

            }

        }

    }

    private List<TopicAssignment> getTopicsToAssignForTags( List<ContentVersion> files, Map<ID, ConversionResult> contentDocumentIdToConversionResultMap ) {

        // topic already assigned to files
        // need to identify which file tags aren't already assigned as topics
        Map<ID, Set<String>> contentDocumentIdToTopicNamesMap = getTopicNamesByContentDocumentIdMap( files, contentDocumentIdToConversionResultMap );

        // all the topics that match to file tags
        // use this map to lookup the topic to assign to a file
        // once identiy which tags/topics aren't already assigned to the files
        Map<String, Topic> tagNameToTopicMap = getOrCreateTopicByTagNameMap( files, contentDocumentIdToConversionResultMap );

        List<TopicAssignment> topicsToAssign = new List<TopicAssignment>();

        for ( ContentVersion file : files ) {

            System.debug( file );

            if ( String.isNotBlank( file.TagCsv ) ) {

                // remember, the topic names are lowercase so we can do case-insensitive contains
                Set<String> assignedTopicNames = contentDocumentIdToTopicNamesMap.get( file.ContentDocumentId );

                for ( String tagName : Tag2Topic_Utils.split( file.TagCsv, ',' ) ) {

                    String lowerTagName = tagName.toLowerCase();

                    if ( assignedTopicNames == null || !assignedTopicNames.contains( lowerTagName ) ) {

                        System.debug( 'need to assign topic: ' + lowerTagName );

                        Topic topicForTagName = tagNameToTopicMap.get( lowerTagName );

                        if ( topicForTagName != null ) {

                            System.debug( 'assigning topic: ' + topicForTagName );

                            topicsToAssign.add( new TopicAssignment(
                                EntityId = file.ContentDocumentId,
                                Topic = new Topic( Name = tagName ) // topic name is unique external id, and this is an easy way to pass around the topic name
                            ));

                        } else {

                            System.debug( 'no topic exists for tag: ' + lowerTagName );

                        }

                    } else {

                        System.debug( 'already assigned topic: ' + lowerTagName );

                    }

                }

            } else {

                System.debug( 'skipping file, not assigned any tags' );

            }

        }

        return topicsToAssign;
    }

    /**
     * Use this method to determine which topics have been assigned to the files.
     *
     * Returns a map whose keys are ContentDocumentIds and values are
     * set of already assigned topic names (lowercase).
     */
    private Map<ID, Set<String>> getTopicNamesByContentDocumentIdMap( List<ContentVersion> files, Map<ID, ConversionResult> contentDocumentIdToConversionResultMap ) {

        Set<ID> contentDocumentIds = getContentDocumentIds( files );

        // topics that are already assigned to documents
        // if tag name matches a topic name in this map, then don't redundantly assign topic to file
        Map<ID, Set<String>> contentDocumentIdToTopicNamesMap = new Map<ID, Set<String>>();

        for ( List<TopicAssignment> assignments : [
                SELECT TopicId, Topic.Name, EntityId
                FROM TopicAssignment
                WHERE EntityId IN :contentDocumentIds
        ] ) {
            for ( TopicAssignment assignment : assignments ) {
                Set<String> topicNames = contentDocumentIdToTopicNamesMap.get( assignment.EntityId );
                if ( topicNames == null ) {
                    topicNames = new Set<String>();
                    contentDocumentIdToTopicNamesMap.put( assignment.EntityId, topicNames );
                }
                topicNames.add( assignment.Topic.Name.toLowerCase() );
            }
        }

        return contentDocumentIdToTopicNamesMap;
    }

    /**
     * Use this method to determine (tagName => topic) among the given files.
     * This lets you know which tags do or do not need to be created as topics.
     *
     * Returns a map whose keys are tag names (lowercase) assigned to the given files,
     * and the map values are the Topic records with the same tag names.
     *
     * If a Topic does not exist with same name as a tag (case-insensitive),
     * then this method creates new Topics.
     *
     * The returned map will have an entry for each tag among the files.
     */
    private Map<String, Topic> getOrCreateTopicByTagNameMap( List<ContentVersion> files, Map<ID, ConversionResult> contentDocumentIdToConversionResultMap ) {

        Map<String, Topic> tagNameToTopicMap = getTopicByTagNameMap( files );

        // identify tags that are not yet topics
        for ( ContentVersion file : files ) {
            if ( String.isNotBlank( file.TagCsv ) ) {
                for ( String tagName : Tag2Topic_Utils.split( file.TagCsv, ',' ) ) {
                    String lowerTagName = tagName.toLowerCase();
                    if ( !tagNameToTopicMap.containsKey( lowerTagName ) ) {
                        System.debug( 'new topic: ' + tagName );
                        tagNameToTopicMap.put( lowerTagName, new Topic( Name = tagName ) );
                    } else {
                        System.debug( 'topic already exists: ' + tagName );
                    }
                }
            }
        }

        Boolean allOrNone = false;
        List<Topic> topics = tagNameToTopicMap.values();
        List<Database.UpsertResult> upsertResults = Database.upsert( topics, allOrNone );

        for ( Integer i = 0; i < upsertResults.size(); i++ ) {

            Database.UpsertResult upsertResult = upsertResults[i];
            Topic t = topics[i];

            if ( !upsertResult.isSuccess() ) {

                // if failed to upsert topic then note issue on all conversion results
                // of files with the same tag name as the topic that failed to upsert

                List<String> errorMessages = new List<String>();

                for ( Database.Error err : upsertResult.getErrors() ) {
                    errorMessages.add( err.getMessage() );
                }

                // find all the files who has a tag with the same name
                // as the topic that failed to save and add the error message(s)
                // to those file conversion results
                for ( ContentVersion file : files ) {
                    if ( String.isNotBlank( file.TagCsv ) ) {
                        for ( String tagName : Tag2Topic_Utils.split( file.TagCsv, ',' ) ) {
                            if ( tagName.equalsIgnoreCase( t.Name ) ) {
                                ConversionResult conversionResult = contentDocumentIdToConversionResultMap.get( file.ContentDocumentId );
                                conversionResult.messages.addAll( errorMessages );
                                conversionResult.status = ConversionResultStatus.ERROR;
                            }
                        }
                    }
                }

            }

        }

        return tagNameToTopicMap;
    }

    /**
     * Returns a map whose keys are the tag names (lowercase) assigned to the given files
     * and whose values are the topic records with those tag names.
     *
     * A map entry only exists if a topic record exists for a tag name.
     */
    private Map<String, Topic> getTopicByTagNameMap( List<ContentVersion> files ) {

        Set<String> tagNames = getTagNames( files );

        // topics that already exist that match tag names
        // these are candidates for topic assignment
        // if a tag name exists in this map, then don't redundantly create topic
        Map<String, Topic> tagNameToTopicMap = new Map<String, Topic>();

        for ( List<Topic> topics : [
            SELECT Id, Name
            FROM Topic
            WHERE Name IN :tagNames
        ] ) {
            for ( Topic t : topics ) {
                tagNameToTopicMap.put( t.Name.toLowerCase(), t );
            }
        }

        return tagNameToTopicMap;
    }

    /**
     * Returns the unique set of ContentDocumentIds from the given files.
     */
    private Set<ID> getContentDocumentIds( List<ContentVersion> files ) {

        Set<ID> contentDocumentIds = new Set<ID>();

        for ( ContentVersion file : files ) {
            contentDocumentIds.add( file.ContentDocumentId );
        }

        return contentDocumentIds;
    }

    /**
     * Returns the unique set of tags assigned to the given files.
     */
    private Set<String> getTagNames( List<ContentVersion> files ) {

        Set<String> tagNames = new Set<String>();

        for ( ContentVersion file : files ) {
            if ( String.isNotBlank( file.TagCsv ) ) {
                tagNames.addAll( Tag2Topic_Utils.split( file.TagCsv, ',' ) );
            }
        }

        return tagNames;
    }

    // --------------------------------------------

    public class ConversionResult {

        // was conversion success? skipped? error?
        public ConversionResultStatus status { get; set; }

        // id of the file version whose tags to convert to topics
        public ID contentVersionId { get; set; }

        // id of the file document whose tags to convert to topics
        public ID contentDocumentId { get; set; }

        // any pertinent message
        public Set<String> messages { get; set; }

        public ConversionResult() {
            this.messages = new Set<String>();
        }

    }

    public enum ConversionResultStatus {
        CONVERTED, SKIPPED, ERROR
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