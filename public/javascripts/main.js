$(document).ready(function () {
    // **************
    // COMMON
    // **************
    var $window = jQuery(window);

    // -- SIDE BAR
    /*setTimeout(function () {
      $('.bs-docs-sidenav').affix({
      offset: {
      top: function () { return $window.width() <= 980 ? 290 : 210 }
      , bottom: 270
      }
      })
      }, 100)*/

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
	window.location.hash = this.hash;
	$('html,body').scrollTop(scrollmem);
    });
    // -- Bootstrap widget calls
    // jQuery('.dropdown-toggle').dropdown();
    // jQuery(".alert").alert();

    $('.popoverlink').popover();
    $('.tooltiplink').tooltip();

    jQuery('.wrapped-channelml .table-border-summary').addClass('table');
    // jQuery(":submit").addClass('btn btn-success btn-large');
    jQuery('button').addClass('btn');
    jQuery('.jstElements button').addClass('btn-square');
    jQuery('.jstElements').addClass('btn-group');
    jQuery('.buttons a').addClass("btn");
    replaceIconWithFontAwesome();

    // make code pretty
    window.prettyPrint && prettyPrint();

    // **************
    // HEADER
    // **************
    /*jQuery("#header_menu > ul").addClass("pull-right");
      jQuery("#header_menu > ul").append('<li id="loggedelement"></li>');
      jQuery("#loggedas > a").appendTo("#loggedelement");
      jQuery("#loggedas").remove();*/


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
    var splitProjectName = jQuery('#pname').html();
    if (splitProjectName != undefined) {
	splitProjectName = splitProjectName.split("-");
	jQuery('#pname').html(jQuery.trim(splitProjectName[0]) + " <small>" + jQuery.trim(splitProjectName[1]) + "</small>");
    }

    // -- Transforms redmine selected in bootstrap active flag
    jQuery(".tabli").attr("data-toggle", "tab");

    // -- Builds the nav menu in the ovewview section
    jQuery("#project_overview_sections section").each(function () {
	var id = jQuery(this).attr("id");
	var name = jQuery(this).find(".page-header h2").html();
	jQuery("#project_overview_list").append("<li><a href='#" + id + "'><i class='icon-chevron-right'></i>" + name + "</a></li>");
    });

    jQuery('#project_overview_list li').click(function (e) {
	jQuery('#project_overview_list li').removeClass('active');

	var $this = jQuery(this);
	if (!$this.hasClass('active')) {
	    $this.addClass('active');
	}

    });



});

var currentModel = undefined;

// This method adds filtering abilities to a text input and a linked list
function setupFilter(idFilter, idList) {
    jQuery(idFilter).keyup(function () {
	var a = jQuery(this).val();
	if (a.length > 2) {
	    // this finds all links in the list that contain the input,
	    // and hide the ones not containing the input while showing the ones that do
	    var containing = jQuery(idList + ' li').filter(function () {
		var regex = new RegExp('\\b' + a, 'i');
		return regex.test(jQuery('a', this).text());
	    }).slideDown();
	    jQuery(idList + ' li').not(containing).slideUp();
	}
	else {
	    jQuery(idList + ' li').slideDown();
	}
    });
}


function replaceIconWithFontAwesome() {

    jQuery("a.icon-add").removeClass("icon-add").prepend("<icon class='icon-plus'/>");
    jQuery("a.icon-edit").removeClass("icon-edit").prepend("<icon class='icon-edit'/>");
    jQuery("a.icon-copy").removeClass("icon-copy").prepend("<icon class='icon-copy'/>");
    jQuery("a.icon-duplicate").removeClass("icon-duplicate").prepend("<icon class='icon-copy'/>");
    jQuery("a.icon-del").removeClass("icon-del").prepend("<icon class='icon-trash'/>");
    jQuery("a.icon-move").removeClass("icon-move").prepend("<icon class='icon-move'/>");
    jQuery("a.icon-save").removeClass("icon-save").prepend("<icon class='icon-save'/>");
    jQuery("a.icon-cancel").removeClass("icon-cancel").prepend("<icon class='icon-remove'/>");
    jQuery("a.icon-multiple").removeClass("icon-multiple").prepend("<icon class='icon-th-large'/>");
    jQuery("a.icon-folder").removeClass("icon-folder").prepend("<icon class='icon-folder-open-alt'/>");

    jQuery("a.open").removeClass("icon-folder").prepend("<icon class='icon-folder-open-alt'/>");

    jQuery("a.icon-package").removeClass("icon-package").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-user").removeClass("icon-user").prepend("<icon class='icon-user'/>");
    jQuery("a.icon-projects").removeClass("icon-projects").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-help").removeClass("icon-help").prepend("<icon class='icon-help'/>");
    jQuery("a.icon-attachment").removeClass("icon-attachment").prepend("<icon class='icon-paper-clip'/>");
    jQuery("a.icon-history").removeClass("icon-history").prepend("<icon class='icon-time'/>");
    jQuery("a.icon-time").removeClass("icon-time").prepend("<icon class='icon-time'/>");
    jQuery("a.icon-time-add").removeClass("icon-time-add").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-stats").removeClass("icon-stats").prepend("<icon class='icon-bar-chart'/>");
    jQuery("a.icon-warning").removeClass("icon-warning").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-fav").removeClass("icon-fav").prepend("<icon class='icon-heart'/>");
    jQuery("a.icon-fav-off").removeClass("icon-fav-off").prepend("<icon class='icon-heart-empty'/>");
    jQuery("a.icon-reload").removeClass("icon-reload").prepend("<icon class='icon-repeat'/>");
    jQuery("a.icon-lock").removeClass("icon-lock").prepend("<icon class='icon-lock'/>");
    jQuery("a.icon-unlock").removeClass("icon-unlock").prepend("<icon class='icon-unlock'/>");
    jQuery("a.icon-checked").removeClass("icon-checked").prepend("<icon class='icon-check'/>");
    jQuery("a.icon-details").removeClass("icon-details").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-report").removeClass("icon-report").prepend("<icon class='icon-list-alt'/>");
    jQuery("a.icon-comment").removeClass("icon-comment").prepend("<icon class='icon-comment'/>");
    jQuery("a.icon-summary").removeClass("icon-summary").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-server-authentication").removeClass("icon-server-authentication").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-issue").removeClass("icon-issue").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-zoom-in").removeClass("icon-zoom-in").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-zoom-out").removeClass("icon-zoom-out").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-passwd").removeClass("icon-passwd").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-test").removeClass("icon-test").prepend("<icon class='icon-folder-open-alt'/>");
    jQuery("a.icon-file").removeClass("icon-file").prepend("<icon class='icon-file'/>");


    // JSTB

    jQuery(".jstb_strong").removeClass("jstb_strong").prepend("<icon class='icon-bold'/>");
    jQuery(".jstb_em").removeClass("jstb_em").prepend("<icon class='icon-italic'/>");
    jQuery(".jstb_ins").removeClass("jstb_ins").prepend("<icon class='icon-underline'/>");
    jQuery(".jstb_del").removeClass("jstb_del").prepend("<icon class='icon-strikethrough'/>");
    jQuery(".jstb_code").removeClass("jstb_code").prepend("<icon class='icon-code'/>");
    jQuery(".jstb_h1").removeClass("jstb_h1").prepend("<icon class='icon-h1'/>");
    jQuery(".jstb_h2").removeClass("jstb_h2").prepend("<icon class='icon-h2'/>");
    jQuery(".jstb_h3").removeClass("jstb_h3").prepend("<icon class='icon-h3'/>");
    jQuery(".jstb_ul").removeClass("jstb_ul").prepend("<icon class='icon-list-ul'/>");
    jQuery(".jstb_ol").removeClass("jstb_ol").prepend("<icon class='icon-list-ol'/>");
    jQuery(".jstb_bq").removeClass("jstb_bq").prepend("<icon class='icon-indent-right'/>");
    jQuery(".jstb_unbq").removeClass("jstb_unbq").prepend("<icon class='icon-indent-left'/>");
    jQuery(".jstb_pre").removeClass("jstb_pre").prepend("<icon class='icon-pre'/>");
    jQuery(".jstb_link").removeClass("jstb_link").prepend("<icon class='icon-link'/>");
    jQuery(".jstb_img").removeClass("jstb_img").prepend("<icon class='icon-picture'/>");
    jQuery(".jstb_help").removeClass("jstb_help").prepend("<icon class='icon-question-sign'/>");

    // DT

    jQuery(".E_issue").prepend('<icon class="icon-edit"/>');
    jQuery(".E_issue-edit").prepend('<icon class="icon-edit"/>');
    jQuery(".E_issue-closed").prepend('<icon class="icon-edit"/>');
    jQuery(".E_issue-note").prepend('<icon class="icon-edit"/>');
    jQuery(".E_changeset").prepend('<icon class="icon-cog"/>');
    jQuery(".E_news").prepend('<icon class="icon-bullhorn"/>');
    jQuery(".E_message").prepend('<icon class="icon-comment"/>');
    jQuery(".E_reply").prepend('<icon class="icon-reply"/>');
    jQuery(".E_wiki-page").prepend('<icon class="icon-font"/>');
    jQuery(".E_attachment").prepend('<icon class="icon-paper-clip"/>');
    jQuery(".E_document").prepend('<icon class="icon-file-alt"/>');
    jQuery(".E_project").prepend('<icon class="icon-book"/>');
    jQuery(".E_time-entry").prepend('<icon class="icon-time"/>');


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

function showErrorMessageInOSBExplorer(file, message) {
    decodedfile = decodeURIComponent(file);
    if (file.indexOf("github") != -1) {
	repoFilePath = decodedfile.replace('raw.githubusercontent', 'github').replace('/master/', '/blob/master/');
    }
    else if (file.indexOf("github")) {
	repoFilePath = decodedfile.replace('/raw/default/', '/src/default/');
    }

    // If there isn't webgl support display warn message
    jQuery(".project-main").hide();
    jQuery(".project-main").before("<div id='geppettoContainer'><div id='osbexplorermessage'></div>");
    jQuery("#osbexplorermessage").html(message + "<br /><br /> You can also <a href='" + decodedfile + "' target='_blank'>download the file</a> or <a href='" + repoFilePath + "' target='_blank'>view the file content online</a>.<br /><br />");
}

function hideFooter() {
    $('#main').css("padding-bottom", "0px");
    $('footer').hide();
}

function showFooter() {
    $('#main').css("padding-bottom", "120px");
    $('footer').show();
}

function toggleProjectButton() {
    if ($("#showGeppettoBtn").is(":visible")) {
	$("#showGeppettoBtn").hide();
	$("#showProjectBtn").show();
	$("#moreBtn").hide();
    }
    else {
	$("#showGeppettoBtn").show();
	$("#showProjectBtn").hide();
	$("#moreBtn").show();
    }
}

function showGeppetto() {
    toggleProjectButton();
    $("#geppettoContainer").show();
    $(".project-main").hide();
    $(".project-header").hide()
    hideFooter();
    //	$('#main').css("background-color","rgb(35, 35, 35)");
    //	$('#main').css("color","white");
}

function showProject() {
    var projectUrl = '//' + location.host + location.pathname;
    if (history.pushState) { history.pushState(null, null, projectUrl); }
    toggleProjectButton();
    $("#geppettoContainer").hide();
    $(".project-main").show();
    $(".project-header").show();
    showFooter();
    //	$('#main').css("background-color","white");
    //	$('#main').css("color","black");
}


function loadDiscussOSB() {
    $("#discussOSB").html('<iframe id="forum_embed_2" src="javascript:void(0)" scrolling="no" frameborder="0" width="100%" height="700"></iframe>');
    document.getElementById("forum_embed_2").src = "https://groups.google.com/forum/embed/?place=forum/osb-discuss&showsearch=true&showpopout=true&parenturl=" + encodeURIComponent(window.location.href);
}

function loadAnnounceOSB() {
    $("#announceOSB").html('<iframe id="forum_embed" src="javascript:void(0)" scrolling="no" frameborder="0" width="100%" height="700"></iframe>');
    document.getElementById("forum_embed").src = "https://groups.google.com/forum/embed/?place=forum/osb-announce&showsearch=true&showpopout=true&parenturl=" + encodeURIComponent(window.location.href);
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
	showErrorMessageInOSBExplorer(file, "Your graphics card does not seem to support <a href='http://khronos.org/webgl/wiki/Getting_a_WebGL_Implementation'>WebGL</a>.<br />Find out how to get it <a href='http://get.webgl.org/'>here</a>.");
        return false;
    }
    else if (!checkCookie()) {
	showErrorMessageInOSBExplorer(file, "Sorry, your cookies are disabled in your browser. Please, enable them if you want to use OSB 3D Explorer.");
        return false;
    }
    return true;
}

function addGeppettoIframe(src) {
    $(".project-header").before("<div id='geppettoContainer'><iframe id='geppettoFrame' src=" + $("#geppettoIP").val() + $("#geppettoContextPath").val() + src + "></iframe></div>");
    setTimeout(function(){window.frames["geppettoFrame"].contentWindow.postMessage({ "command": "window.osbURL='http://"+location.host + location.pathname+"';"}, $("#geppettoIP").val());},8000);
}

function sendProjectToIframe(uri) {
    window.frames["geppettoFrame"].contentWindow.postMessage({"command": "removeWidgets" }, $("#geppettoIP").val());
    window.frames["geppettoFrame"].contentWindow.postMessage($.extend({"command": "loadSimulation"}, uri), $("#geppettoIP").val());
    window.frames["geppettoFrame"].contentWindow.postMessage({"command": "window.osbURL='http://"+location.host + location.pathname+"';"}, $("#geppettoIP").val());
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
