// Utils for calling Geppetto web service

//////////////////////
// GENERAL METHOD //
//////////////////////
function callGeppetto(url, onloadFunction, authenticate){
    // If authentication is needed first we check if it is already logged in otherwise we log in
    if (authenticate){
	makeCorsRequest("currentuser", processCurrentUser, url, onloadFunction);
    }
    else{
	makeCorsRequest(url, onloadFunction);
    }
}
function makeCorsRequest(url, onloadFunction, url2, onPostLoadFunction) {
    if (hasGeppettoServer && checkCookie()){

	var xhr = createCORSRequest('GET', geppettoIP + geppettoContextPath + url);
	if (!xhr) {
	    console.log('CORS not supported');
	    return;
	}
	
	// Response handlers.
	xhr.onload = function() {
	    var text = xhr.responseText;
	    //	console.log('Response from CORS request to ' + url + ':' + text);
	    onloadFunction(text, url2, onPostLoadFunction);
	};
	
	xhr.onerror = function() {
	    console.log('Error making the request to ' + geppettoIP + geppettoContextPath + url + '. Check Geppetto server.');
            // If we're logging in, continue anyway
            if (url.startsWith('logout'))
	        onloadFunction(xhr.responseText, url2, onPostLoadFunction);
	};
	
	xhr.withCredentials = true;
	xhr.send();
    }  
    else{
	onloadFunction(text, url2, onPostLoadFunction);
    }
}
//Create the XHR object.
function createCORSRequest(method, url) {
    var xhr = new XMLHttpRequest();
    if ("withCredentials" in xhr) {
        // XHR for Chrome/Firefox/Opera/Safari.
        xhr.open(method, url, true);
    } else if (typeof XDomainRequest != "undefined") {
        // XDomainRequest for IE.
        xhr = new XDomainRequest();
        xhr.open(method, url);
    } else {
        // CORS not supported.
        xhr = null;
    }
    return xhr;
}

//////////////////////
// SPECIFIC METHODS //
//////////////////////

// Add dashboard in home page
function addDashboard(){
    $("#dashboardContainer").prepend("<iframe id='geppettoDashboard' style='width:100%;height:100%;border:0px;' src='" + geppettoIP + geppettoContextPath + "'></iframe>");
    window.addEventListener('message', function(e){
    	if (e.data.command == 'ready') {
            var dashboard = $("#geppettoDashboard");
            if (dashboard.length > 0) {
    		dashboard[0].contentWindow.postMessage({"command": "$('.well').css('background-color','white')"}, $("#geppettoIP").val()+"/currentuser");
    		dashboard[0].contentWindow.postMessage({"command": "$('.dark-well').css('background-color','white')"}, $("#geppettoIP").val()+"/currentuser");
    		dashboard[0].contentWindow.postMessage({"command": "$('.navbar').css('background-color','white')"}, $("#geppettoIP").val()+"/currentuser");
    		dashboard[0].contentWindow.postMessage({"command": "$('footer').css('background-color','white')"}, $("#geppettoIP").val()+"/currentuser");
    		dashboard[0].contentWindow.postMessage({"command": "$('body').css('padding-top','0')"}, $("#geppettoIP").val()+"/currentuser");
    		dashboard[0].contentWindow.postMessage({"command": "$('#header').remove()"}, $("#geppettoIP").val()+"/currentuser");
    		dashboard[0].contentWindow.postMessage({"command": "if($('.project-preview').length==0){$('.dashboardAlert').html(\"You don't have any models yet! Why don\'t you start Exploring OSB and persisting any model you are interested in? All the models you will persist will appear here in your home so you can easily come back to them. Click on the help tab for more!\");}"}, $("#geppettoIP").val()+"/currentuser");
            }
    	    
    	}
    }, false);
    
}

function addSampleProjectsToHome(){
    addSampleProjects('#learnMoreContainer');
    $('#learnMoreContainer').show();
}

function addSampleProjectsToExploreOSB(){
    addSampleProjects('#welcomeMainContainer');
    $('#welcomeMainContainerLoadDialog').remove();
}

function addSampleProjects(target){
    makeCorsRequest("currentuser", processCurrentUser, "geppettoProjectsCompact", function(data) {
	var jsonData=JSON.parse(data);
	for(var i=0;i<jsonData.length;i++){
	    var geppettoProjectUrl=geppettoIP+geppettoContextPath+"geppetto?load_project_from_id="+jsonData[i].id;
	    var iconClass="gpt-neuron sampleModelIcon"; //the default
	    switch(jsonData[i].name) {
	    case "Primary Auditory Cortex Network":
		iconClass="acnet2SampleThumbnail sampleThumbnail";
		break;
	        
	    case "CA1 Pyramidal Cell":
		iconClass="ca1SampleThumbnail sampleThumbnail";
		break;
	        
	    case "Izhikevich Spiking Neuron Model":
		iconClass="izhiSampleThumbnail sampleThumbnail";
		break;
	        
	    case "L23 Cell":
		iconClass="l23SampleThumbnail sampleThumbnail";
		break;
	        
	    case "Hodgkin-Huxley Neuron":
		iconClass="hhcellSampleThumbnail sampleThumbnail";
		break;
	    }
	    
	    $(target).append("<div class='sampleModel' onclick='showSampleProject(\""+geppettoProjectUrl+"\")'><div class='"+iconClass+"'></div><a class='sampleModelLabel'>"+jsonData[i].name+"</a></div>");	
	}
	
    });	
}

function showSampleProject(url){
    var ifr=$('<iframe/>', {id:'geppettoSampleProject', src:url, style: 'width:100%;height:100%;border:0px;'});
    window.setTimeout(function(){
        ifr.show();
        $("footer").hide();
    }, 2000);
    ifr.on("load",
            function(){
                $(".indexNoUser").hide();
                history.replaceState(null, document.title, location.pathname+"#!/sampleProject");
                history.pushState(null, document.title, location.pathname);

                window.addEventListener("popstate", function() {
                    if(location.hash === "#!/sampleProject") {
            	        history.replaceState(null, document.title, location.pathname);
            	        location.replace("/");
                    }
                }, false);
                
            	$("#geppettoSampleProject")[0].contentWindow.postMessage({"command": "$('.HomeButton').hide()"}, $("#geppettoIP").val());
                
            });
    $('#geppettoHomeContainer').append(ifr);
    $('#geppettoHomeContainer').show();
}

// Process login. Validate login was successful and execute next call/function if needed
function processLogin(text, url, onloadFunction){
    //FIXME: Add validation
    if (url !== ""){
	makeCorsRequest(url, onloadFunction);
    }
    else{
	onloadFunction();	
    }
}

// Process OSB Login
function processOSBLogin(url, text){
    $('form').trigger('submit');
};

// Process current user. If it is not logged in, sign in as an anonymous user (if it is not logged in Redmine) or with the Geppetto user 
function processCurrentUser(text, url2, onloadFunction){
    //var logged = false;
    if (text === "" ){
	//FIXME: Theoretically it is impossible for a user to be logged in with a different user while trying to sign in 
	// However this bit was implemented in order to deal with this corner case.
	// It is not working now as Geppetto doesn't allow to relogin with a different user. We should implement logout and logged in in order to avoid this problem 
	//var loggedUser = JSON.parse(text);
	//if (loggedUser.login === redmineLogin || (loggedUser.login === 'osbanonymous' && redmineLogin === '')){
	//logged = true;
	//}
	
	var parameters = "username=osbanonymous&password=anonymous";
	if (redmineLogin != ""){
	    parameters = "username=" + redmineLogin + "&password=" + redmineHashed;
	}	
	makeCorsRequest("login?" + parameters + "&outputFormat=json", processLogin, url2, onloadFunction);
    }
    else{
	if (url2 != ""){
	    makeCorsRequest(url2, onloadFunction);
	}
	else{
	    onloadFunction();
	}
    }
};
