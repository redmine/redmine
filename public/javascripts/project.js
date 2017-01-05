$(document).ready(function(){
    //$("#pname").after("");
 
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

    $("#moreBtn").click(function(){
	clearTimeout(projectBtnPopover);
	$("#showGeppettoBtn").popover("destroy");
    });

    $("#showProjectBtn").click(function(){
        var projectUrl = '//' + location.host + location.pathname;
	if(history.pushState) {history.pushState(null, null, projectUrl);}
	toggleProjectButton();
	$("#geppettoContainer").hide();
	$(".project-main").show();
        $(".project-header").show();
	showFooter();
        //showProject();
    });

    projectBtnPopover=setTimeout(function(){ if($("#geppettoContainer")[0]==undefined){$("#showGeppettoBtn").popover("show");} }, 3000);

    setTimeout(function(){ $("#showGeppettoBtn").popover("destroy"); }, 5000);

    if (isProjectOrShowcase) {
        if (repourl && project_repository != "" && ((neuroml2files != "") || (swcfiles != ""))) {
            var submenus = {"networks": networkfiles, "channels": channelfiles,
                            "synapses": synapsefiles, "cells": cellfiles,
                            "other": neuroml2files, "swc": swcfiles};
            for (var submenu in submenus) {
                var files = submenus[submenu];
                // capitalize title
                var menu_title = submenu.charAt(0).toUpperCase() + submenu.slice(1);
                if (submenus[submenu] != "") {
                    $("#explorermenu").append("<li class=\"menu-item dropdown dropdown-submenu pull-left explorerSubmenu\"><a class=\"dropdown-toggle\" data-toggle=\"dropdown\" tabindex=-1 href=#>"+ menu_title +"</a><ul class=dropdown-menu id=\""+ submenu +"-menu\"></ul></li>");
                    for (var i=0; i<networkfiles.length; i++) {
                        var file = files[i];
                        var basename = file.split('/').slice(-1)[0];
                        $("#"+submenu+"-menu").append("<li class=\"submenu-item\" id=" + basename + "><a href=# tabindex=-1 id=\""+ file + "\">"+ file +"</a></li>");
                    }
                }
            }
        } else {
            $("#explorermenu").append("<li><a tabindex=-1>No NeuroML2 or SWC files found!</a></li>");
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
	    var filenameEscape = modelKey.concat(".nml").replace(/([ #;?&,.+*~\':"!^$[\]()=>|\/@])/g,"\\$1");
	    var subMenu = "<ul class=dropdown-menu>";
	    for (var projectKey in currentProjectDict[modelKey]){
	        subMenu += "<li><a href=# tabindex=-1 onclick=open3DExplorer(" + currentProjectDict[modelKey][projectKey].id + ",'<%= @project.identifier%>');>Project: " + modelKey + "</a></li>";
	    }	
	    subMenu += "<li><a href=# tabindex=-1 onclick=" + $("[id=" + filenameEscape + "]").find('a').attr("onclick") + ">New Project</a></li>";
	    subMenu += "</ul>";	
	    //This can be used to parse the id if we use to whole path instead of the file name .replace(/([ #;?&,.+*~\':"!^$[\]()=>|\/@])/g,"\\\\$1");
	    // Delete link for the parent option
	    $("[id=" + filenameEscape + "]").append(subMenu);
	    $("[id=" + filenameEscape + "]").first('a').removeAttr("href").prop('onclick',null).off('click');
	    // Add dropdown option
	    $("[id=" + filenameEscape + "]").addClass('dropdown-submenu');
        }
    };

    if (repourl && (project_repository != "") && (neuroml2files != "")) {
        callGeppetto("projectswithref?reference=" + project_identifier, processCurrentProjects, true);
    }

   $("#showGeppettoBtn").click(function(){
        open3DExplorer(encodeURIComponent(getMainModel(repourl+repopath, defaultMainModel)), project_identifier, "true");
    });

    $(".explorerSubmenu li[class='submenu-item']").click(function(){
        var filename = $(this).children().attr("id");
        open3DExplorer(encodeURIComponent(repourl+repopath+filename), project_identifier);
    });

    
});
