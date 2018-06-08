({
    doInit: function ( component, event, helper ) {

        helper.enqueueAction( component, 'c.getTopicAssignments', {
            'entityId' : component.get( 'v.recordId' )
        }).then( $A.getCallback( function( topicAssignments ) {
            component.set( 'v.topicAssignments', topicAssignments );
        }));

    }
})