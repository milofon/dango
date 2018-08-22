/**
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-07-03
 */

module dango.web.controllers;

public
{
    import dango.web.controller : WebController;
}

private
{
    import dango.system.container;
    import dango.web.controller : registerController;

    import dango.web.controllers.fileshare;
    // import dango.web.controllers.fileupload;
}



class WebControllersContext : ApplicationContext
{
    override void registerDependencies(ApplicationContainer container)
    {
        container.registerController!(FileShareWebControllerFactory, FileShareWebController);
        // container.registerFactory!(FileUploadWebControllerFactory, FileUploadWebController);
    }
}

