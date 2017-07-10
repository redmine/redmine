$(document).ready(function(){

    // 'activate' selected tab in project navbar
    $("li > .selected").parent().addClass("active");

    var geturl=getParameterByName('explorer');
    var projectId=getParameterByName('explorer_id');
    if(geturl != '')
        open3DExplorer(geturl, project_identifier);
    else if(projectId != '')
        openExistingProjectIn3DExplorer(projectId);

    function toggleProjectButton(){
	if($("#showGeppettoBtn").is(":visible")){
	    $("#showGeppettoBtn").hide();
	    $("#showProjectBtn").show();
	    $("#moreBtn").hide();
	}
	else{
	    $("#showGeppettoBtn").show();
	    $("#showProjectBtn").hide();
	    $("#moreBtn").show();
	}
    }

    function hasModels(){
        return (repourl && project_repository != "" && ((neuroml2files != "") || (swcfiles != "")));
    }
    var doFilter = function (){
        var filter, lis, a;
        filter = this.value.toUpperCase();
        lis = $(".submenu-item");

        if (filter)
            $(".collapse").collapse("show");
        else
            $(".collapse").collapse("hide");
        
        // Loop through all list items, and hide those who don't match the search query
        for (var i = 0; i < lis.length; i++) {
            a = lis[i].getElementsByTagName("a")[0];
            if (a.innerHTML.toUpperCase().indexOf(filter) > -1) {
                lis[i].style.display = "";
            } else {
                lis[i].style.display = "none";
            }
        }

        var menus = $(".explorerSubmenu");
        for (var i = 0; i < menus.length; i++) {
            if ($(menus[i]).find("a > ul > li:not([style*='display: none'])").length == 0) {
                menus[i].style.display = "none";
            } else {
                menus[i].style.display = "";
            }
        }

        if ($(".explorerSubmenu > a > ul > li:not([style*='display: none'])").length == 0) {
            $(".no-match").css('display', 'block');
        } else {
            $(".no-match").css('display', 'none');
        }
    }

    $("#modelFilter").keyup(doFilter);
    $(".cl-icon").click(doFilter);
    $(".cl-icon").removeClass("btn");

    if (!hasModels()) {
        $("#moreBtn").hide();
        $("#showGeppettoBtn").hide();
    }

    $("#showProjectBtn").click(function(){
        var projectUrl = '//' + location.host + location.pathname;
	if(history.pushState) {history.pushState(null, null, projectUrl);}
	toggleProjectButton();
        $("#geppettoContainer").remove();
	$(".project-main").show();
        $(".project-header").show();
	showFooter();
    });

    if (isProjectOrShowcase) {
        if (hasModels()){
            var submenus = {"curated": jsonfiles, "networks": networkfiles, "channels": channelfiles,
                            "synapses": synapsefiles, "cells": cellfiles, "swc": swcfiles};
            for (var submenu in submenus) {
                var files = submenus[submenu];
                // capitalize title
                var menu_title = submenu.charAt(0).toUpperCase() + submenu.slice(1);
                if (submenus[submenu] != "") {
                    $("#explorermenu").append("<li class=\"explorerSubmenu\"><a data-toggle=\"collapse\" data-parent=\"#accordion\" class=\"collapsed\" href=\"#collapse" + submenu + "\">"+ menu_title +"</span> <i class=\"icon-caret-right\"></i><ul role=\"tabpanel\" class=\"collapse \" id=\"collapse" + submenu + "\"></ul></li>");
                    for (var i=0; i<files.length; i++) {
                        var file = files[i];
                        var basename = file.split('/').slice(-1)[0];
                        $("#"+"collapse"+submenu).append("<li class=\"submenu-item\" id=" + basename + "><a href=# tabindex=-1 id=\""+ file + "\">"+ basename +"</a></li>");
                    }
                }
            }
            callGeppetto("projectswithref?reference=" + project_identifier, processCurrentProjects, true);}
    else {
            $("#explorermenu").append("<li>No NeuroML2 or SWC files found!</li>");
        }
    }

    function processCurrentProjects(text){
        var currentProjects = JSON.parse(text);
        var currentProjectDict = {};
        
        //Iterate over the geppetto projects and create a dictionary by models
        for (projectIndex in currentProjects){
	    var projectName = currentProjects[projectIndex].name.split(" - ");
	    
	    if (!(projectName[0] in currentProjectDict)){
	        currentProjectDict[projectName[0]] = [];
	    }
	    
	    currentProjectDict[projectName[0]].push(currentProjects[projectIndex]);
        }
        
        //Create a submenu with all the geppetto projects plus a New Project option
        for (var modelKey in currentProjectDict){
	    var filenameEscape = modelKey.concat(".nml").replace(/([ \[#;?&,.+*~\':"!^$\]()=>|\/@])/g,"\\$1");
	    var subMenu = "<ul class=\"projects\">";
	    for (var projectKey in currentProjectDict[modelKey]){
	        subMenu += "<li class=\"submenu-item user-project\"><a href=# tabindex=-1 id=" + currentProjectDict[modelKey][projectKey].id + ">Project:" + modelKey + "</a></li>";
	    }	
	    subMenu += "<li class=\"submenu-item user-project\"><a href=# tabindex=-1 id=" + modelKey + ">New Project</a></li>";
	    subMenu += "</ul>";	
	    //This can be used to parse the id if we use to whole path instead of the file name .replace(/([ #;?&,.+*~\':"!^$[\]()=>|\/@])/g,"\\\\$1");
	    // Delete link for the parent option
	    $("[id=" + filenameEscape + "]").append(subMenu);
	    $("[id=" + filenameEscape + "]").first('a').removeAttr("href").prop('onclick',null).off('click');
        }
        $("ul li[class='submenu-item user-project']").click(function(){
            var id = $(this).children().attr("id");
            if (!isNaN(parseInt(id))) {
                open3DExplorer(parseInt(id), project_identifier);
            } else {
                id = $(this).parent().prev().attr("id");
                open3DExplorer(encodeURIComponent(repourl+repopath+id), project_identifier);
            }
        });
    };

   $("#showGeppettoBtn").click(function(){
       open3DExplorer(encodeURIComponent(getMainModel(repourl+repopath, defaultMainModel)), project_identifier);
       hideFooter();
    });

    $(".explorerSubmenu li[class='submenu-item'] a").click(function(){
        var id = $(this).attr("id");
        open3DExplorer(encodeURIComponent(repourl+repopath+id), project_identifier);
    });

    $(".delete_tag").click(function(){deleteTag(project_identifier,$(this).attr("id")); return false;});

    $("#add_new_tag").click(function(){addNewTag(project_identifier,$("#new_tag").val()); return false;});

    $(".collapse")
        .on('shown.bs.collapse', function(){
            $(this).parent().find(".icon-caret-right").removeClass("icon-caret-right").addClass("icon-caret-down");
        })
        .on('hidden.bs.collapse', function(){
            $(this).parent().find(".icon-caret-down").removeClass("icon-caret-down").addClass("icon-caret-right");
        });
});
