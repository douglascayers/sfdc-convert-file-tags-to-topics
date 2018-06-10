Convert File Tags to Topics
==============================

Overview
--------

In development.

Convert file tags to topics to use [Summer '18 Topics component](https://releasenotes.docs.salesforce.com/en-us/summer18/release-notes/rn_general_topics_on_records.htm) in Lightning Experience.

Inspired by [Jos Dofferhoff](https://success.salesforce.com/_ui/core/chatter/groups/GroupProfilePage?g=0F93A0000009SE1&fId=0D53A00003f1lod).

Files have a unique sharing model as compared to other records.
A user can query for files (ContentDocument or ContentVersion) but will only get results back that are
explicitly shared to the user or a group the user belongs to. For best results, the user must query
through the ContentDocumentLink object filtering by the records that file is shared with.
This is true regardless if the user is an admin with "View All Data" or "Modify All Data".
This brings up interesting scenarios to try and handle that are non-trivial.

Use cases:
* Convert tags to topics for files that are shared to libraries
* Convert tags to topics for files that are shared to records
* Convert tags to topics for a single file

To receive conversion error emails, add your Salesforce user as an [Apex Exception Email Recipient](https://help.salesforce.com/articleView?id=code_apex_exceptions.htm&type=5).
Or, you can periodically monitor the **Tag2Topic Log** object for new records.

In Setup, ensure under **Topics for Object Settings** that Topics are enabled for the **Content Document** object.

As the user performing the tags-to-topics conversion, you must have membership to the libraries whose files are to be converted,
or you must have at least read access to the records the files are shared with if you scope conversion to specific entities.

Credits
=======

[Doug Ayers](https://douglascayers.com) develops and maintains the project.

[Neil Hayek](https://success.salesforce.com/ProfileView?userId=00530000003SpRm), Salesforce Files Expert, for providing solution design and guidance.
