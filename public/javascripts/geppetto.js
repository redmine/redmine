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
		console.log('Woops, there was an error making the request to ' + url);  
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
	jQuery("#welcomeMainContainer").prepend("<div class='span12' style='margin-bottom: 20px;'><iframe id='geppettoDashboard' style='width:100%;height:550px;border:0px;' src='" + geppettoIP + geppettoContextPath + "'></iframe></div>");
}
// Process logout
function processLogout(url, text){
	$('#logout_link').unbind('click').click();
};
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
