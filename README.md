Convert File Tags to Topics
==============================

Overview
--------

Convert file tags to topics to use [Summer '18 Topics component](https://releasenotes.docs.salesforce.com/en-us/summer18/release-notes/rn_general_topics_on_records.htm) in Lightning Experience.

In Lightning Experience, file tags are not editable. Product managers have indicated that the future of tagging files will be through Topics.
This project aims to help you migrate from file tags (Classic) to file topics (Lightning).

Inspired by [Jos Dofferhoff](https://success.salesforce.com/_ui/core/chatter/groups/GroupProfilePage?g=0F93A0000009SE1&fId=0D53A00003f1lod).

Documentation and Discussion
--------------------------

* Read the [wiki page](https://github.com/douglascayers/sfdc-convert-file-tags-to-topics/wiki) for further documentation on Convert File Tags to Topics.
* Read the [FAQ page](https://github.com/douglascayers/sfdc-convert-file-tags-to-topics/wiki/Frequently-Asked-Questions) to help troubleshoot technical issues.
* Raise well defined issues and ideas via the [Issues feature](https://github.com/douglascayers/sfdc-convert-file-tags-to-topics/issues).

Pre-Requisites
--------------

There are a few items you need to setup before installing and using this app.

1. In Setup, ensure under **Topics for Object Settings** that Topics are enabled for the **Content Document** object.
2. Add the [Topics component](https://help.salesforce.com/articleView?id=collab_topics_records_admin_LEX.htm&type=5) to the Lightning Record Page for the **Content Document** object. 
3. As the user performing the tags-to-topics conversion, you must have [membership to the libraries](https://help.salesforce.com/articleView?id=content_workspace_create.htm&type=5) whose files are to be converted
or you must have at least read [access to the records the files are shared with](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contentdocumentlink.htm).

Please see the [instructions in the wiki](https://github.com/douglascayers/sfdc-convert-file-tags-to-topics/wiki/Pre-Requisites-Instructions) for screen shots and step-by-steps.


Packaged Release History
========================

Support
-------

File Tags to Topics Converter is an open source project. It's an independent project with its ongoing development happening in the evenings and weekends.
Maintaining and developing new features takes a considerable amount of time. If your business has found value in my projects, please consider [showing
your support](https://douglascayers.com/thanks-for-your-support/) by contributing to my [virtual tip jar on PayPal](https://www.paypal.me/douglascayers/). Thank you! ❤️

Release 1.0 (current)
-----------
* In Development

---

Installing the Source Code (Developers)
---------------------------------------

You may install the unmanaged code from GitHub and make any desired adjustments.
You are responsible for ensuring unit tests meet your org's validation rules and other requirements.
You can conveniently deploy the source to a new scratch org using [Andy Fawcett](https://andyinthecloud.com/category/githubsfdeploy/)'s deploy tool:

[![Deploy from GitHub](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com?owner=douglascayers&repo=convert-file-tags-to-topics)


Credits
=======

[Doug Ayers](https://douglascayers.com) develops and maintains the project.

[Neil Hayek](https://success.salesforce.com/ProfileView?userId=00530000003SpRm), Salesforce Files Expert, for providing solution design and guidance.


License
=======

The source code is licensed under the [BSD 3-Clause License](LICENSE)