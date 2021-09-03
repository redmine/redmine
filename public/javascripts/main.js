$(document).ready(function () {
    // **************
    // COMMON
    // **************
    var $window = $(window);
    var hash = window.location.hash;
    if (hash) {
	var selectedTab = $('.nav li a[href="' + hash + '"]');
	selectedTab.trigger('click', true);
	if (hash == "#workspace")
	    hideFooter();
    }

    $('.nav-tabs a, .nav-stacked a').click(function (e) {
	$(this).tab('show');
	var scrollmem = $('body').scrollTop() || $('html').scrollTop();
	$('html,body').scrollTop(scrollmem);
    });
    // -- Bootstrap widget calls
    $('.popoverlink').popover();
    $('.tooltiplink').tooltip();

    $('.wrapped-channelml .table-border-summary').addClass('table');
    // $(":submit").addClass('btn btn-success btn-large');
    $('button').addClass('btn');
    $('.jstElements button').addClass('btn-square');
    $('.jstElements').addClass('btn-group');
    $('.buttons a').addClass("btn");
    replaceIconWithFontAwesome();

    // make code pretty
    window.prettyPrint && prettyPrint();

    // **************
    // HEADER
    // **************
    $("#searchLink").click(function () {
	$(this).closest("form").submit();
	return false;
    });

    $("#toolsLink").click(function () {
	$(this).children("icon")
	    .toggleClass("icon-plus-sign")
	    .toggleClass("icon-minus-sign");
	$("#project_quick_jump_box").toggle();
    });

    $(".logout-btn").click(function() {
        callGeppetto("logout?outputFormat=json",
                     // use default button event to logout redmine after geppetto logged out
                     function(){ $(".logout-btn").off('click').click(); }, false);
        return false;
    });

    // **************
    // PROJECT PAGE
    // **************

    // -- Split the project name field in two in the title bar
    var splitProjectName = $('#pname').html();
    if (splitProjectName != undefined) {
	splitProjectName = splitProjectName.split("-");
	$('#pname').html($.trim(splitProjectName[0]) + " <small>" + $.trim(splitProjectName[1]) + "</small>");
    }

    // -- Transforms redmine selected in bootstrap active flag
    $(".tabli").attr("data-toggle", "tab");

    // -- Builds the nav menu in the ovewview section
    $("#project_overview_sections section").each(function () {
	var id = $(this).attr("id");
	var name = $(this).find(".page-header h2").html();
	$("#project_overview_list").append("<li><a href='#" + id + "'><i class='icon-chevron-right'></i>" + name + "</a></li>");
    });

    $('#project_overview_list li').click(function (e) {
	$('#project_overview_list li').removeClass('active');

	var $this = $(this);
	if (!$this.hasClass('active')) {
	    $this.addClass('active');
	}

    });

    // add Geppetto Projects to the My Projects dropdown menu
    function populateMyProjects(json) {
        var geppettoProjects = JSON.parse(json);
        for (var i=0; i<geppettoProjects.length; ++i) {
            $('.projects-dropdown + .dropdown-menu').append(
                "<li selected=selected><a href=" + window.location.origin + "/projects/" + geppettoProjects[i].name +
                    "?explorer_id=" + geppettoProjects[i].id + ">" + geppettoProjects[i].name + "</a></li>"
            );
        }
    }
    callGeppetto("geppettoProjectsCompact", populateMyProjects, true);

});

var currentModel = undefined;

// This method adds filtering abilities to a text input and a linked list
function setupFilter(idFilter, idList) {
    $(idFilter).keyup(function () {
	var a = $(this).val();
	if (a.length > 2) {
	    // this finds all links in the list that contain the input,
	    // and hide the ones not containing the input while showing the ones that do
	    var containing = $(idList + ' li').filter(function () {
		var regex = new RegExp('\\b' + a, 'i');
		return regex.test($('a', this).text());
	    }).slideDown();
	    $(idList + ' li').not(containing).slideUp();
	}
	else {
	    $(idList + ' li').slideDown();
	}
    });
}


function replaceIconWithFontAwesome() {
    $("a.icon-add").removeClass("icon-add").prepend("<icon class='icon-plus'/>");
    $("a.icon-edit").removeClass("icon-edit").prepend("<icon class='icon-edit'/>");
    $("a.icon-copy").removeClass("icon-copy").prepend("<icon class='icon-copy'/>");
    $("a.icon-duplicate").removeClass("icon-duplicate").prepend("<icon class='icon-copy'/>");
    $("a.icon-del").removeClass("icon-del").prepend("<icon class='icon-trash'/>");
    $("a.icon-move").removeClass("icon-move").prepend("<icon class='icon-move'/>");
    $("a.icon-save").removeClass("icon-save").prepend("<icon class='icon-save'/>");
    $("a.icon-cancel").removeClass("icon-cancel").prepend("<icon class='icon-remove'/>");
    $("a.icon-multiple").removeClass("icon-multiple").prepend("<icon class='icon-th-large'/>");
    $("a.icon-folder").removeClass("icon-folder").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.open").removeClass("icon-folder").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-package").removeClass("icon-package").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-user").removeClass("icon-user").prepend("<icon class='icon-user'/>");
    $("a.icon-projects").removeClass("icon-projects").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-help").removeClass("icon-help").prepend("<icon class='icon-help'/>");
    $("a.icon-attachment").removeClass("icon-attachment").prepend("<icon class='icon-paper-clip'/>");
    $("a.icon-history").removeClass("icon-history").prepend("<icon class='icon-time'/>");
    $("a.icon-time").removeClass("icon-time").prepend("<icon class='icon-time'/>");
    $("a.icon-time-add").removeClass("icon-time-add").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-stats").removeClass("icon-stats").prepend("<icon class='icon-bar-chart'/>");
    $("a.icon-warning").removeClass("icon-warning").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-fav").removeClass("icon-fav").prepend("<icon class='icon-heart'/>");
    $("a.icon-fav-off").removeClass("icon-fav-off").prepend("<icon class='icon-heart-empty'/>");
    $("a.icon-reload").removeClass("icon-reload").prepend("<icon class='icon-repeat'/>");
    $("a.icon-lock").removeClass("icon-lock").prepend("<icon class='icon-lock'/>");
    $("a.icon-unlock").removeClass("icon-unlock").prepend("<icon class='icon-unlock'/>");
    $("a.icon-checked").removeClass("icon-checked").prepend("<icon class='icon-check'/>");
    $("a.icon-details").removeClass("icon-details").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-report").removeClass("icon-report").prepend("<icon class='icon-list-alt'/>");
    $("a.icon-comment").removeClass("icon-comment").prepend("<icon class='icon-comment'/>");
    $("a.icon-summary").removeClass("icon-summary").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-server-authentication").removeClass("icon-server-authentication").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-issue").removeClass("icon-issue").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-zoom-in").removeClass("icon-zoom-in").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-zoom-out").removeClass("icon-zoom-out").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-passwd").removeClass("icon-passwd").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-test").removeClass("icon-test").prepend("<icon class='icon-folder-open-alt'/>");
    $("a.icon-file").removeClass("icon-file").prepend("<icon class='icon-file'/>");

    // JSTB
    $(".jstb_strong").removeClass("jstb_strong").prepend("<icon class='icon-bold'/>");
    $(".jstb_em").removeClass("jstb_em").prepend("<icon class='icon-italic'/>");
    $(".jstb_ins").removeClass("jstb_ins").prepend("<icon class='icon-underline'/>");
    $(".jstb_del").removeClass("jstb_del").prepend("<icon class='icon-strikethrough'/>");
    $(".jstb_code").removeClass("jstb_code").prepend("<icon class='icon-code'/>");
    $(".jstb_h1").removeClass("jstb_h1").prepend("<icon class='icon-h1'/>");
    $(".jstb_h2").removeClass("jstb_h2").prepend("<icon class='icon-h2'/>");
    $(".jstb_h3").removeClass("jstb_h3").prepend("<icon class='icon-h3'/>");
    $(".jstb_ul").removeClass("jstb_ul").prepend("<icon class='icon-list-ul'/>");
    $(".jstb_ol").removeClass("jstb_ol").prepend("<icon class='icon-list-ol'/>");
    $(".jstb_bq").removeClass("jstb_bq").prepend("<icon class='icon-indent-right'/>");
    $(".jstb_unbq").removeClass("jstb_unbq").prepend("<icon class='icon-indent-left'/>");
    $(".jstb_pre").removeClass("jstb_pre").prepend("<icon class='icon-pre'/>");
    $(".jstb_link").removeClass("jstb_link").prepend("<icon class='icon-link'/>");
    $(".jstb_img").removeClass("jstb_img").prepend("<icon class='icon-picture'/>");
    $(".jstb_help").removeClass("jstb_help").prepend("<icon class='icon-question-sign'/>");

    // DT
    $(".E_issue").prepend('<icon class="icon-edit"/>');
    $(".E_issue-edit").prepend('<icon class="icon-edit"/>');
    $(".E_issue-closed").prepend('<icon class="icon-edit"/>');
    $(".E_issue-note").prepend('<icon class="icon-edit"/>');
    $(".E_changeset").prepend('<icon class="icon-cog"/>');
    $(".E_news").prepend('<icon class="icon-bullhorn"/>');
    $(".E_message").prepend('<icon class="icon-comment"/>');
    $(".E_reply").prepend('<icon class="icon-reply"/>');
    $(".E_wiki-page").prepend('<icon class="icon-font"/>');
    $(".E_attachment").prepend('<icon class="icon-paper-clip"/>');
    $(".E_document").prepend('<icon class="icon-file-alt"/>');
    $(".E_project").prepend('<icon class="icon-book"/>');
    $(".E_time-entry").prepend('<icon class="icon-time"/>');
}

function getParameterByName(name) {
    name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
    var regexS = "[\\?&]" + name + "=([^&#]*)";
    var regex = new RegExp(regexS);
    var results = regex.exec(window.location.href);
    if (results == null)
	return "";
    else
	return decodeURIComponent(results[1].replace(/\+/g, " "));
}

function showErrorMessageInOSBExplorer(message, file) {
    decodedfile = decodeURIComponent(file);
    if (file.indexOf("github") != -1) {
	repoFilePath = decodedfile.replace('raw.githubusercontent', 'github').replace('/master/', '/blob/master/');
    }
    else if (file.indexOf("github")) {
	repoFilePath = decodedfile.replace('/raw/default/', '/src/default/');
    }

    // If there isn't webgl support display warn message
    $(".project-main").hide();
    $(".project-main").before("<div id='geppettoContainer'><div id='osbexplorermessage'></div>");
    if (file) {
        $("#osbexplorermessage").html(message + "<br /><br /> You can also <a href='" + decodedfile + "' target='_blank'>download the file</a> or <a href='" + repoFilePath + "' target='_blank'>view the file content online</a>.<br /><br />");
    }
}

function hideFooter() {
    $('#main').css("padding-bottom", "0px");
    $('footer').hide();
}

function showFooter() {
    $('#main').css("padding-bottom", "120px");
    $('footer').show();
}

function hasModels(){
    return (repourl && project_repository != "" && ((neuroml2files != "") || (swcfiles != "")));
}

function toggleProjectButton() {
    if ($("#showGeppettoBtn").is(":visible") || !hasModels()) {
        if (hasModels()) {
            $("#showGeppettoBtn").hide();
            $("#moreBtn").hide();
        }
        if ($("#showProjectBtn").is(":visible")) {
            $("#showProjectBtn").hide();
            $("#troubleshootExplorerBtn").hide();
        }
        else {
            $("#showProjectBtn").show();
            $("#troubleshootExplorerBtn").show();
        }
    }
    else {
        if (hasModels()) {
            $("#showGeppettoBtn").show();
            $("#moreBtn").show();
        }
        $("#showProjectBtn").hide();
        $("#troubleshootExplorerBtn").hide();
    }
}

function showGeppetto() {
    toggleProjectButton();
    $("#geppettoContainer").show();
    $(".project-main").hide();
    $(".project-header").hide()
    hideFooter();
}

function showProject() {
    var projectUrl = '//' + location.host + location.pathname;
    if (history.pushState) { history.pushState(null, null, projectUrl); }
    toggleProjectButton();
    $("#geppettoContainer").hide();
    $(".project-main").show();
    $(".project-header").show();
    showFooter();
}

function getMainModel(pathToRepo, defaultModel) {
    var mainModelUrl = pathToRepo;
    $.ajax({
	type: 'GET',
	dataType: 'text',
	async: false,
	cache: false,
	url: mainModelUrl + "_osb.yml",
	success: function (responseData, textStatus, jqXHR) {
	    var nativeObject = YAML.parse(responseData);
	    mainModelUrl = mainModelUrl + nativeObject.mainModel;
	},
	error: function (responseData, textStatus, errorThrown) {
	    mainModelUrl = mainModelUrl + defaultModel;
	}
    });
    return mainModelUrl;
}

function checkBrowserCapabilities() {
    if (!Detector.webgl) {
	showErrorMessageInOSBExplorer("Your graphics card does not seem to support <a href='http://khronos.org/webgl/wiki/Getting_a_WebGL_Implementation'>WebGL</a>.<br />Find out how to get it <a href='http://get.webgl.org/'>here</a>.");
        return false;
    }
    else if (!checkCookie()) {
	showErrorMessageInOSBExplorer("Sorry, your cookies are disabled in your browser. Please, enable them if you want to use OSB 3D Explorer.");
        return false;
    }
    return true;
}

function addGeppettoIframe(src) {
    $(".project-header").before("<div id='geppettoContainer'><iframe id='geppettoFrame' src=" + $("#geppettoIP").val() + $("#geppettoContextPath").val() + src + "></iframe></div>");
    setTimeout(function(){
        window.frames["geppettoFrame"].contentWindow.postMessage({ "command": "window.osbURL='http://"+location.host+"/';"}, $("#geppettoIP").val());
        window.frames["geppettoFrame"].contentWindow.postMessage({"command": "$('.HomeButton').hide()"}, $("#geppettoIP").val());
	window.frames["geppettoFrame"].contentWindow.postMessage({"command": "window.dropboxKey = \""+dropboxKey+"\";"}, $("#geppettoIP").val());
    },8000);
}

function sendProjectToIframe(uri) {
    window.frames["geppettoFrame"].contentWindow.postMessage({"command": "removeWidgets" }, $("#geppettoIP").val());
    window.frames["geppettoFrame"].contentWindow.postMessage($.extend({"command": "loadSimulation"}, uri), $("#geppettoIP").val());
    window.frames["geppettoFrame"].contentWindow.postMessage({"command": "window.osbURL='http://"+location.host+"/';"}, $("#geppettoIP").val());
    window.frames["geppettoFrame"].contentWindow.postMessage({"command": "$('.HomeButton').hide()"}, $("#geppettoIP").val());
}

function openExistingProjectIn3DExplorer(projectId) {
    showGeppetto();
    if (checkBrowserCapabilities()) {
	//Change url without reloading page
	var explorerUrl = '//' + location.host + location.pathname + '?explorer_id=' + projectId;
	if (history.pushState) { history.pushState(null, null, explorerUrl); }

	if ($("#geppettoContainer").length == 0)
            addGeppettoIframe("geppetto?load_project_from_id=" + projectId);
        else
            sendProjectToIframe({"projectId": projectId});

        currentModel = projectId;
    }
}

function open3DExplorer(uri, projectIdentifier) {
    showGeppetto();
    if (checkBrowserCapabilities()) {
	//Change url without reloading page
	if (typeof uri === 'string') {
	    if (currentModel != uri) {
                var explorerUrl = '//' + location.host + location.pathname + '?explorer=' + encodeURIComponent(uri);
	        if (history.pushState) { history.pushState(null, null, explorerUrl); }

		if (uri.endsWith(".json")) {
		    //This is a session, we don't need to invoke the servlet
		    if ($("#geppettoContainer").length == 0)
                        addGeppettoIframe("geppetto?load_project_from_url=" + uri);
                    else
                        sendProjectToIframe({"url": uri});
		}
		else {
		    //This is a NeuroML or SWC file, let's invoke the servlet to generate a Geppetto project on the fly
		    $.ajax({
			url: "/projects/" + projectIdentifier + "/generateGEPPETTOSimulationFile?explorer=" + uri,
			cache: false,
			success: function (json) {
			    if (json.error) {
				alert(json.error);
			    }
			    else {
				var urlGeppettoFile = $("#serverIP").val() + json.geppettoSimulationFile;

				if ($("#geppettoContainer").length == 0)
                                    addGeppettoIframe("geppetto?load_project_from_url=" + urlGeppettoFile);
                                else
                                    sendProjectToIframe({"url": urlGeppettoFile});
			    }
			}
		    });
		}
	    }
	}
	else {
	    openExistingProjectIn3DExplorer(uri);
	}
        currentModel = uri;
    }
}

function addNWBIframe(src) {
  var iframe = $("<iframe id='geppettoFrame' src='http://nwbexplorer.opensourcebrain.org/nwbfile="+decodeURIComponent(src)+"'></iframe>")
  $(".project-header").before("<div id='geppettoContainer'></div>");
  $("#geppettoContainer").append(iframe);
  //iframe.load(function() { sendNWBToIframe(src); });
}

function sendNWBToIframe(uri) {
  let frame = document.getElementById("geppettoFrame");
  frame.src = "http://nwbexplorer.opensourcebrain.org/nwbfile="+uri;
  //  frame.contentWindow.postMessage(decodeURIComponent(uri), '*');
}

function openNWBExplorer(uri, projectIdentifier) {
    showGeppetto();
    if (checkBrowserCapabilities()) {
	//Change url without reloading page
	if (typeof uri === 'string') {
	    if (currentModel != uri) {
                var explorerUrl = '//' + location.host + location.pathname + '?explorer=' + encodeURIComponent(uri);
	        if (history.pushState) { history.pushState(null, null, explorerUrl); }
		if ($("#geppettoContainer").length == 0)
                    addNWBIframe(uri);
                else
                    sendNWBToIframe(uri);
	    }
	}
        currentModel = uri;
    }
}

function addNetPyNEIframe(src) {
  var iframe = $("<iframe id='geppettoFrame' src='http://netpyne.opensourcebrain.org'></iframe>")
  $(".project-header").before("<div id='geppettoContainer'></div>");
  $("#geppettoContainer").append(iframe);
  iframe.load(function() {
    // FIXME: this is bad...    
    var uri = decodeURIComponent(src);
    var components = uri.split('.com/')[1].split('/');
    var params = {repo: components[0]+'/'+components[1]};
    var components = components.splice(3);
    params.moduleName = components.splice(-1)[0].split('.')[0];
    params.path = components.join('/');
    sendNetPyNEToIframe(params);
  });
}

function sendNetPyNEToIframe(params) {
  let frame = document.getElementById("geppettoFrame");
  frame.contentWindow.postMessage(params, '*');
}

function openNetPyNEUI(uri, projectIdentifier) {
  showGeppetto();
  if (checkBrowserCapabilities()) {
    //Change url without reloading page
    if (typeof uri === 'string') {
      if (currentModel != uri) {
        var explorerUrl = '//' + location.host + location.pathname + '?explorer=' + encodeURIComponent(uri);
	if (history.pushState) { history.pushState(null, null, explorerUrl); }
	if ($("#geppettoContainer").length == 0)
          addNetPyNEIframe(uri);
        else
          sendNetPyNEToIframe(uri);
      }
    }
    currentModel = uri;
  }
}

function checkCookie() {
    var cookieEnabled = (navigator.cookieEnabled) ? true : false;
    if (typeof navigator.cookieEnabled == "undefined" && !cookieEnabled) {
	document.cookie = "testcookie";
	cookieEnabled = (document.cookie.indexOf("testcookie") != -1) ? true : false;
    }
    return cookieEnabled;
}

// Google Analytics
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-29853802-1']);
_gaq.push(['_trackPageview']);

(function () {
    var ga = document.createElement('script');
    ga.type = 'text/javascript';
    ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0];
    s.parentNode.insertBefore(ga, s);
})();
