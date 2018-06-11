Convert File Tags to Topics
==============================

Overview
--------

Convert file tags to topics to use [Summer '18 Topics component](https://releasenotes.docs.salesforce.com/en-us/summer18/release-notes/rn_general_topics_on_records.htm) in Lightning Experience.

Inspired by [Jos Dofferhoff](https://success.salesforce.com/_ui/core/chatter/groups/GroupProfilePage?g=0F93A0000009SE1&fId=0D53A00003f1lod).

Setup
-----

1. In Setup, ensure under **Topics for Object Settings** that Topics are enabled for the **Content Document** object.

2. Add the **Topics** component to your file pages, use [App Builder](https://trailhead.salesforce.com/en/modules/lightning_app_builder) to customize the Lightning Record Page for **Content Document** object.

3. As the user performing the tags-to-topics conversion, you must have [membership to the libraries](https://help.salesforce.com/articleView?id=content_workspace_create.htm&type=5) whose files are to be converted
or you must have at least read [access to the records the files are shared with](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentdocumentlink.htm).

4. Install the package ([Production]()) ([Sandbox]()).

5. Assign yourself the permission set **Convert File Tags to Topics**.

6. Go to the tab **Convert File Tags to Topics**.
  * Select which files whose tags to convert
  * Click Submit button, this launches a background batch apex job
 

Error Notifications
-------------------

To receive conversion error emails, add your Salesforce user as an [Apex Exception Email Recipient](https://help.salesforce.com/articleView?id=code_apex_exceptions.htm&type=5).
Or, you can periodically monitor the **Tag2Topic Log** object for new records.

Resources
---------

See Salesforce documentation to learn more about setting up [Salesforce CRM Content and Libraries](https://help.salesforce.com/articleView?id=collab_admin_crm_content.htm&type=5).

Credits
=======

[Doug Ayers](https://douglascayers.com) develops and maintains the project.

[Neil Hayek](https://success.salesforce.com/ProfileView?userId=00530000003SpRm), Salesforce Files Expert, for providing solution design and guidance.
