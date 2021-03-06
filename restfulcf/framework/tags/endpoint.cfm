<cfsetting enablecfoutputonly="yes">
<!--- -->
<fusedoc fuse="restfulcf/framework/tags/endpoint.cfm" language="ColdFusion" specification="2.0">
	<responsibilities>
		I am the custom tag that pulls all REST requests together
	</responsibilities>
</fusedoc>
--->

<!--- tags get called twice if there are closing tags --->
<cfif thisTag.executionMode NEQ "start"><cfexit method="exittemplate"></cfif>

<!--- must provide name and engine; reload and debug options are optional --->
<cfparam name="attributes.name" type="string">
<cfparam name="attributes.engine" type="string">
<cfparam name="attributes.reload" type="boolean" default="false">
<!--- optional parameter of somewhere to put the response for further processing --->
<cfparam name="attributes.response" type="string">

<!--- reset any previously generated content straight away --->
<cfcontent reset="true">

<!--- intialise the RestfulCF instance engine if required --->
<cfif NOT structKeyExists(application, "_restfulcf") OR attributes.reload>
	<cfset variables.app = createobject("component", attributes.engine)>
	<cflock scope="application" type="exclusive" timeout="25" throwontimeout="true">
		<cfset application['_restfulcf'][attributes.name] = variables.app>
	</cflock>
	<cfset variables.app.init()>
</cfif>

<!--- work out the request method (PUT and DELETE can be simulated via a POST using a _method=X parameter) --->
<cfset variables.request_method = cgi.request_method>
<cfif variables.request_method EQ "POST">
	<cfif structkeyexists(url, "_method") AND listfind("PUT,DELETE", url['_method'])>
		<cfset variables.request_method = ucase(url['_method'])>
		<cfset structdelete(url, "_method")>
	</cfif>
	<cfif structkeyexists(form, "_method") AND listfind("PUT,DELETE", form['_method'])>
		<cfset variables.request_method = ucase(form['_method'])>
		<cfset structdelete(form, "_method")>
		<cfif structkeyexists(form, "fieldnames") AND listfindnocase(form.fieldnames, "_method")>
			<cfset form.fieldnames = listdeleteat(form.fieldnames, listfindnocase(form.fieldnames, "_method"))>
		</cfif>
	</cfif>
</cfif>

<!--- dispatch the request --->
<cfset variables.response = application['_restfulcf'][attributes.name].dispatch(variables.request_method, cgi.path_info)>

<!--- set the location header if there's anything to set (e.g. after a create) --->
<cfif len(variables.response.getResponseURI())><cfheader name="Location" value="#variables.response.getResponseURI()#"></cfif>
<!--- serve up binary content straight from a file if there's a filename --->
<cfif len(variables.response.getResponseFile())>
	<cfif fileexists(variables.response.getResponseFile())>
		<cfcontent reset="true" type="#variables.response.getResponseType()#" file="#variables.response.getResponseFile()#">
	<cfelse>
		<cfset variables.response.setStatusCode("404")>
		<cfset variables.response.setStatusText("Static file not found")>
	</cfif>
<!--- output main content if anything's been generated --->
<cfelseif len(variables.response.getResponseBody())>
	<!--- special handling of XML in case the response isn't actually XML at all... --->
	<cfif variables.response.getResponseType() EQ "application/xml">
		<cfif isxml(variables.response.getResponseBody())>
			<cfset variables.response.setResponseBody('<?xml version="1.0" encoding="UTF-8"?>#chr(10)#' & variables.response.getResponseBody())>
		<cfelse>
			<cfset variables.response.setResponseType("text/html")>
		</cfif>
	</cfif>
	<cfcontent reset="true" type="#variables.response.getResponseType()#"><cfoutput>#variables.response.getResponseBody()#</cfoutput>
</cfif>
<cfif len(variables.response.getStatusText())>
	<cfheader statuscode="#variables.response.getStatusCode()#" statustext="#variables.response.getStatusText()#">
<cfelse>
	<cfheader statuscode="#variables.response.getStatusCode()#">
</cfif>

<!--- push the response object out if required --->
<cfif structkeyexists(attributes, "response")><cfset caller[attributes.response] = variables.response></cfif>
