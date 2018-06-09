/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-file-tags-to-topics
 * License: BSD 3-Clause License
 */
public without sharing class Tag2Topic_ConversionService {

    public List<ConversionResult> convertTagsToTopics( List<ContentVersion> files ) {

        System.debug( 'Tag2Topic_ConversionService.convertTagsToTopics' );

        List<TopicAssignment> topicsToAssign = getTopicsToAssignForTags( files );

        List<ConversionResult> conversionResults = new List<ConversionResult>();

        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.optAllOrNone = false;

        List<Database.SaveResult> saveResults = Database.insert( topicsToAssign, dmo );

        for ( Integer i = 0; i < saveResults.size(); i++ ) {

            Database.SaveResult saveResult = saveResults[i];

            ConversionResult conversionResult = new ConversionResult();
            conversionResult.status = ( saveResult.isSuccess() ? ConversionResultStatus.CONVERTED : ConversionResultStatus.ERROR );
            conversionResult.contentVersionId = topicsToAssign[i].EntityId;

            if ( !saveResult.isSuccess() ) {

                List<String> messages = new List<String>();

                for ( Database.Error err : saveResult.getErrors() ) {
                    messages.add( err.getMessage() );
                }

                conversionResult.message = String.join( messages, ' ' );

            }

            conversionResults.add( conversionResult );

        }

        return conversionResults;
    }

    // --------------------------------------------

    private List<TopicAssignment> getTopicsToAssignForTags( List<ContentVersion> files ) {

        // topic already assigned to files
        // need to identify which file tags aren't already assigned as topics
        Map<ID, Set<String>> contentDocumentIdToTopicNamesMap = getTopicNamesByContentDocumentIdMap( files );

        // all the topics that match to file tags
        // use this map to lookup the topic to assign to a file
        // once identiy which tags/topics aren't already assigned to the files
        Map<String, Topic> tagNameToTopicMap = getOrCreateTopicByTagNameMap( files );

        List<TopicAssignment> topicsToAssign = new List<TopicAssignment>();

        for ( ContentVersion file : files ) {

            System.debug( file );

            if ( String.isNotBlank( file.TagCsv ) ) {

                // remember, the topic names are lowercase so we can do case-insensitive contains
                Set<String> assignedTopicNames = contentDocumentIdToTopicNamesMap.get( file.ContentDocumentId );

                for ( String tagName : file.TagCsv.split( ',' ) ) {

                    String lowerTagName = tagName.toLowerCase();

                    if ( assignedTopicNames == null || !assignedTopicNames.contains( lowerTagName ) ) {

                        System.debug( 'need to assign topic: ' + lowerTagName );

                        topicsToAssign.add( new TopicAssignment(
                            EntityId = file.ContentDocumentId,
                            TopicId = tagNameToTopicMap.get( lowerTagName ).Id
                        ));

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
    private Map<ID, Set<String>> getTopicNamesByContentDocumentIdMap( List<ContentVersion> files ) {

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
    private Map<String, Topic> getOrCreateTopicByTagNameMap( List<ContentVersion> files ) {

        Map<String, Topic> topicByTagNameMap = getTopicByTagNameMap( files );

        // identify tags that are not yet topics
        for ( ContentVersion file : files ) {
            if ( String.isNotBlank( file.TagCsv ) ) {
                for ( String tagName : file.TagCsv.split( ',' ) ) {
                    if ( !topicByTagNameMap.containsKey( tagName.toLowerCase() ) ) {
                        System.debug( 'new topic: ' + tagName );
                        topicByTagNameMap.put( tagName.toLowerCase(), new Topic( Name = tagName ) );
                    } else {
                        System.debug( 'topic already exists: ' + tagName );
                    }
                }
            }
        }

        upsert topicByTagNameMap.values();

        return topicByTagNameMap;
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
        Map<String, Topic> topicsByTagNameMap = new Map<String, Topic>();

        for ( List<Topic> topics : [
                SELECT Id, Name
                FROM Topic
                WHERE Name IN :tagNames
        ] ) {
            for ( Topic t : topics ) {
                topicsByTagNameMap.put( t.Name.toLowerCase(), t );
            }
        }

        return topicsByTagNameMap;
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
                tagNames.addAll( file.TagCsv.split( ',' ) );
            }
        }

        return tagNames;
    }

    // --------------------------------------------

    public class ConversionResult {

        // was conversion success? skipped? error?
        public ConversionResultStatus status { get; set; }

        // id of the file whose tags to convert to topics
        public ID contentVersionId { get; set; }

        // any pertinent message
        public String message { get; set; }

        public ConversionResult() {
            this.message = '';
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