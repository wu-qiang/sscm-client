package com.oracle.sscm.client.plugins.maven;

import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import java.util.Random;

import com.nimbusds.oauth2.sdk.http.HTTPRequest;
import com.nimbusds.oauth2.sdk.http.HTTPResponse;

import net.minidev.json.JSONArray;
import net.minidev.json.JSONObject;
import net.minidev.json.parser.JSONParser;

@Mojo(name = "generateOccurrences")
public class GrafeasSecurityScanMojo extends AbstractMojo {

    @Parameter(property = "generateOccurrences.dependencyReportJSON", defaultValue = "./dependency-check-report.json")
    private String dependencyReportJSON;

    @Parameter(property = "generateOccurrences.urlGrafeas", defaultValue = "UNKNOWN")
    private String urlGrafeas;
    //
    // Default values for Grafeas Notes and Occurrences:
    //  - <URL>/v1alpha1/projects/{projectInfo.name}/occurrences
    //  - <URL>/v1alpha1/projects/{dependencies[n].vulnerabilities[n].source}/notes
    //
    public static final String URL_SLASH = "/";
    public static final String GRAFEAS_VERSION = "v1alpha1/";
    public static final String GRAFEAS_PROJECTS = "projects/";
    public static final String GRAFEAS_OCCURRENCES_KEY = "occurrences/";
    public static final String GRAFEAS_NOTEID_QUERY_PARAM = "noteId";
    public static final String GRAFEAS_NOTE_NAME = GRAFEAS_PROJECTS + "%s/notes/%s";
    public static final String GRAFEAS_NOTE_NAME_PREFIX = GRAFEAS_VERSION;
    public static final String GRAFEAS_PROJECTS_PREFIX = GRAFEAS_VERSION + GRAFEAS_PROJECTS;
    public static final String GRAFEAS_NOTES = GRAFEAS_PROJECTS_PREFIX + "{projectsId}/notes";
    public static final String GRAFEAS_OCCURRENCES = "%s" + GRAFEAS_PROJECTS_PREFIX + "%s/occurrences";
    public static final String DEFAULT_OWASP_DEPENDENCY_CHECK_REPORT_JSON = "dependency-check-report.json";
    public static final String RANDOMID_CANDIDATE_CHARS = "abcdefghijklmnopqrstuvwxyz-0123456789";


    // Ordered to allow finding the best Confidence from a List
    private enum Confidence {
      LOW, MEDIUM, HIGH, HIGHEST
    }

    private void log(String msg) {
      getLog().info(msg);
    }

    public void execute()
      throws MojoExecutionException {
      // Setup arguments from parameters...
      boolean postGrafeas = false;

      // Location of dependency-check report
      if (new File(dependencyReportJSON).isDirectory()) {
        StringBuilder file = new StringBuilder(dependencyReportJSON);
        if (!dependencyReportJSON.endsWith(File.separator)) file.append(File.separator);
        dependencyReportJSON = file.append(DEFAULT_OWASP_DEPENDENCY_CHECK_REPORT_JSON).toString();
      }

      // Location of Grafeas API server
      if (!urlGrafeas.equals("UNKNOWN")) {
        postGrafeas = true;
        if (!urlGrafeas.endsWith(URL_SLASH)) urlGrafeas += URL_SLASH;
      }

      // Show command line and status when uploading otherwise output
      // will be the JSON for display or to pipe into a file/tool...
      if (postGrafeas) {
        StringBuilder main = new StringBuilder();
        main.append("\n").append(GrafeasSecurityScanMojo.class.getName());
        main.append(" ").append(dependencyReportJSON).append(" ").append(urlGrafeas);
        log(main.toString());
      }

      // Get full path for for information for the OWSAP dependency-check JSON file...
      String projectReportCompleteFileName = dependencyReportJSON;
      try {
        projectReportCompleteFileName = new File(dependencyReportJSON).getCanonicalPath();
      }
      catch (Exception e) { /* ignore */ }

      // Parse the OWSAP dependency-check-report.json...
      JSONObject report = null;
      String projectId = null;
      try {
        if (postGrafeas) log("OWASP dependency-check report: " + projectReportCompleteFileName);
        report = parseDependencyCheckReport(dependencyReportJSON);
        JSONObject projectInfo = (JSONObject) report.get("projectInfo");
        String projectReportDate = (projectInfo != null) ? (String) projectInfo.get("reportDate") : "UNKNOWN";
        projectId = (projectInfo != null) ? (String) projectInfo.get("name"): "UNKNOWN";
        if (postGrafeas) {
          log("OWASP dependency-check report was generated on: " + projectReportDate);
          log("Grafeas {projectsId} for Occurrences: " + projectId);
        }
      }
      catch (Exception e) {
        log("Exception: " + e.toString());
        e.printStackTrace();
        System.exit(1);
      }

      // Generate Grafeas Occurrences base on reported vulnerabilities...
      JSONObject occurrences = new JSONObject();
      try {
        JSONArray listOccurrences = generateOccurrenceList(report);
        if (listOccurrences != null) {
          occurrences.put("occurrences", listOccurrences);
          if (postGrafeas) log("Grafeas Occurrences generated: " + listOccurrences.size());
        }
        else if (postGrafeas) log("No Grafeas Occurrences generated!");
      }
      catch (Exception e) {
        log("Exception: " + e.toString());
        e.printStackTrace();
        System.exit(1);
      }
      //
      // Handle the generated occurrence data:
      //
      // A) Fill out Grafeas URLs then upload (i.e. POST) the results using
      // the Grafeas API checking/creating any Notes for referenced CVEs!
      //
      //   OR
      //
      // B) Output the list of occurrences in their JSON format so that the
      // occurrence JSON data can be saved or piped into another tool!
      //
      // NOTE: The Grafeas URL specified on command line was checked
      //       to ensure that there is a trailing '/' character...
      //
     String urlGrafeasNotes = urlGrafeas + GRAFEAS_NOTES;
     String urlGrafeasNotePrefix = urlGrafeas + GRAFEAS_NOTE_NAME_PREFIX;
     String urlGrafeasOccurrences = String.format(GRAFEAS_OCCURRENCES, urlGrafeas, projectId);
     try {
       JSONArray listOccurrences = (JSONArray) occurrences.get("occurrences");
        if ((listOccurrences != null) && (listOccurrences.size() > 0)) {
          if (postGrafeas) {
            log("Creating Notes at: " + urlGrafeasNotes);
            log("Creating Occurrences at: " + urlGrafeasOccurrences);
            uploadOccurrenceList(listOccurrences, urlGrafeasNotePrefix, urlGrafeasOccurrences);
          }
          else {
            log(occurrences.toJSONString());
          }
        }
        else log("No Occurrences generated from reading file: " + projectReportCompleteFileName);
      }
      catch (Exception e) {
        log("Exception: " + e.toString());
        e.printStackTrace();
        System.exit(1);
      }

      if (postGrafeas) log("\nDone.");
    }

    public String getDependencyReportJSON() {
      return dependencyReportJSON;
    }

    public void setDependencyReportJSON(String dependencyReportJSON) {
      this.dependencyReportJSON = dependencyReportJSON;
    }

    public String getUrlGrafeas() {
        return urlGrafeas;
    }

    public void setUrlGrafeas(String urlGrafeas) {
        this.urlGrafeas = urlGrafeas;
    }

    JSONObject parseDependencyCheckReport(String reportFileName) throws Exception {
      File reportJSON = new File(reportFileName);
      if (!reportJSON.canRead()) {
        log("Unable to read dependency-check report file: " + reportFileName);
        throw new IOException("Cannot Read File: " + reportFileName);
      }

      FileReader in = new FileReader(reportJSON);
      JSONParser parser = new JSONParser(JSONParser.USE_HI_PRECISION_FLOAT | JSONParser.ACCEPT_TAILLING_SPACE);
      //JSONParser parser = new JSONParser(JSONParser.USE_HI_PRECISION_FLOAT);
      Object object = parser.parse(in);
      if (!(object instanceof JSONObject)) {
        log("Unable to read JSON from dependency-check report file: " + reportFileName);
        throw new IOException("No JSON returned from: " + reportFileName);
      }
      return (JSONObject) object;
    }

    private JSONObject parseCreatedOccurrence(String json) throws Exception {
      JSONParser parser = new JSONParser(JSONParser.USE_HI_PRECISION_FLOAT | JSONParser.ACCEPT_TAILLING_SPACE);
      //JSONParser parser = new JSONParser(JSONParser.USE_HI_PRECISION_FLOAT);
      Object object = parser.parse(json);
      if (!(object instanceof JSONObject)) {
        log("Unable to read occurrence JSON: " + json);
        throw new IOException("Unable to parse JSON: " + json);
      }
      return (JSONObject) object;
    }

    JSONArray generateOccurrenceList(JSONObject report) throws Exception {
      JSONArray listOccurrences = null;
      JSONObject projectInfo = (JSONObject) report.get("projectInfo");
      String projectId = (projectInfo != null) ? (String) projectInfo.get("name"): "UNKNOWN";
      //String projectReportDate = (projectInfo != null) ? ((String) projectInfo.get("reportDate")) : "UNKNOWN";
      String projectReportDate_orig = (projectInfo != null) ? ((String) projectInfo.get("reportDate")) : "UNKNOWN";

      projectReportDate_orig = projectReportDate_orig.substring(0,22);
      SimpleDateFormat origFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS");
      SimpleDateFormat targetFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.'999999999Z'");
      String projectReportDate = convertDateFormat(projectReportDate_orig, origFormat, targetFormat);

      // Look through each scanned dependency...
      JSONArray listDependencies = (JSONArray) report.get("dependencies");
      if (listDependencies != null) {
        listOccurrences = new JSONArray();
        for (Object d: listDependencies) {
          JSONObject dependency = (JSONObject) d;

          // Check if any vulnerability was found...
          JSONArray listVulnerabilities = (JSONArray) dependency.get("vulnerabilities");
          if (listVulnerabilities == null) continue;

          // Build the occurrence from the vulnerability and dependency data...
          JSONObject occurrence = null;
          String resourceUrl = createResourceURL(dependency, listDependencies);
          JSONObject packageIssue = createPackageIssue(dependency);

          // For each vulnerability, create occurrence, add info and place into the list of Occurrences...
          for (Object v: listVulnerabilities) {
            JSONObject vulnerability = (JSONObject) v;
            JSONObject issue = (packageIssue != null) ? new JSONObject(packageIssue) : null;
            occurrence = createOccurrenceForVulnerability(vulnerability, issue);
            if (occurrence != null) {
              String randomId = generateRandomChars(RANDOMID_CANDIDATE_CHARS,20);
              occurrence.put("name", GRAFEAS_PROJECTS + projectId + URL_SLASH + GRAFEAS_OCCURRENCES_KEY + randomId);
              occurrence.put("resourceUrl", resourceUrl);
              occurrence.put("createTime", projectReportDate);
              listOccurrences.add(occurrence);
            }
          }
        }
      }
      return listOccurrences;
    }

    private String createResourceURL(JSONObject dependency, JSONArray listDependencies) {
      String fileName = (String) dependency.get("fileName");
      String sha1 = (String) dependency.get("sha1");
      int fileIndex = fileName.indexOf(':');
      if (fileIndex != -1) {
        // Find the base file from the list of dependencies
        boolean found = false;
        String actualName = (fileName.substring(fileIndex+1)).trim();
        String baseName = (fileName.substring(0, fileIndex)).trim();
        for (Object dep: listDependencies) {
          JSONObject d = (JSONObject) dep;
          if (baseName.equalsIgnoreCase((String) d.get("fileName"))) {
            fileName = baseName;
            sha1 = (String) d.get("sha1");
            found = true;
            break;
          }
        }
        if (!found) fileName = actualName;
      }
      return String.format("file://sha1:%s:%s", sha1, fileName);
    }

    private JSONObject createPackageIssue(JSONObject dependency) {
      String cpeUri = null;
      String packageName = null;
      String packageVersion = null;
      JSONObject cpeIdentifier = null;
      Confidence cpeConfidence = null;
      JSONObject packageIdentifier = null;
      Confidence packageConfidence = null;
      JSONObject packageIssue = null;
      JSONObject fixedLocation = null;
      JSONObject affectedLocation = new JSONObject();
      JSONObject affectedVersion = new JSONObject();
      JSONObject fixedVerion = new JSONObject();

      // Find best confidence CPE and Package information
      JSONArray listIdentifiers = (JSONArray) dependency.get("identifiers");
      if (listIdentifiers != null) {
        for (Object id: listIdentifiers) {
          JSONObject identifier = (JSONObject) id;
          Confidence confidence = getConfidence(identifier);
          if ("cpe".equalsIgnoreCase((String) identifier.get("type"))) {
            if (higherConfidence(confidence, cpeConfidence)) {
              cpeConfidence = confidence;
              cpeIdentifier = identifier;
            }
          }
          else {
            if (higherConfidence(confidence, packageConfidence)) {
              packageConfidence = confidence;
              packageIdentifier = identifier;
            }
          }
        }
      }

      // Setup the data based on looking at the identifiers...
      if (cpeIdentifier != null) cpeUri = (String) cpeIdentifier.get("name");
      if (packageIdentifier != null) packageName = (String) packageIdentifier.get("name");

      // Build the package issue details...
      if ((packageName != null) || (cpeUri != null)) {
        packageIssue = new JSONObject();

        // Parse GAV into two parts to cover package information
        if (packageName != null) {
          int versionIndex = packageName.lastIndexOf(':');
          if (versionIndex != -1) {
            packageVersion = packageName.substring(versionIndex+1);
            packageName = packageName.substring(0, versionIndex);
          }
        }

        // Affected package
        if (cpeUri != null) affectedLocation.put("cpeUri", cpeUri);
        if (packageName != null) affectedLocation.put("package", packageName);
        if (packageVersion != null) {
          affectedLocation.put("version", affectedVersion);
          affectedVersion.put("name", packageVersion);
        }

        // Fixed package
        if (packageName != null) {
          fixedLocation = new JSONObject();
          fixedLocation.put("package", packageName);
          fixedLocation.put("version", fixedVerion);
          fixedVerion.put("kind", "MAXIMUM");
        }

        // Package issue
        packageIssue.put("affectedLocation", affectedLocation);
        if (fixedLocation != null) packageIssue.put("fixedLocation", fixedLocation);
      }

      // Return the result...
      return packageIssue;
    }

    private Confidence getConfidence(JSONObject identifier) {
      Confidence confidence;
      try {
        confidence = Confidence.LOW;
        String identifierConfidence = (String) identifier.get("confidence");
        if (identifierConfidence != null)
          confidence = Confidence.valueOf(identifierConfidence);
      }
      catch (Exception e) {
        confidence = Confidence.LOW;
      }
      return confidence;
    }

    private boolean higherConfidence(Confidence confidence, Confidence other) {
      if (confidence == null) return false;
      if (other == null) return true;
      return (confidence.compareTo(other) > 0) ? true : false;
    }

    private JSONObject createOccurrenceForVulnerability(JSONObject vulnerability, JSONObject packageIssue) {
      JSONObject occurrence = null;
      JSONArray listPackageIssues = null;

      // Get CVE data...
      String CVE = (String) vulnerability.get("name");
      String severity = ((String) vulnerability.get("severity")).toUpperCase();
      String source = (String) vulnerability.get("source");
      String noteName = String.format(GRAFEAS_NOTE_NAME, source, CVE);

      // Build the package issue which is actually an array...
      if (packageIssue != null) {
        packageIssue.put("severityName", severity);
        listPackageIssues = new JSONArray();
        listPackageIssues.add(packageIssue);
      }

      // Build the vulnerability details...
      JSONObject vulnerabilityDetails = new JSONObject();
      Double cvssScore = new Double((String) vulnerability.get("cvssScore"));
      vulnerabilityDetails.put("severity", severity);
      vulnerabilityDetails.put("cvssScore", cvssScore);
      if (listPackageIssues != null) vulnerabilityDetails.put("packageIssue", listPackageIssues);

      // Build the occurrence...
      occurrence = new JSONObject();
      occurrence.put("noteName", noteName);
      occurrence.put("kind", "PACKAGE_VULNERABILITY");
      occurrence.put("vulnerabilityDetails", vulnerabilityDetails);

      // Remaining data is filled in from by caller...
      return occurrence;
    }

    private JSONObject createNoteForOccurrence(JSONObject occurrence) {
      JSONObject note = null;

      // Get note data...
      String name = (String) occurrence.get("noteName");
      int cveIndex = name.lastIndexOf('/');
      String CVE = (cveIndex != -1) ? name.substring(cveIndex+1) : name;
      JSONObject vulnerabilityDetails = (JSONObject) occurrence.get("vulnerabilityDetails");
      Double cvssScore = (Double) vulnerabilityDetails.get("cvssScore");
      String severity = (String) vulnerabilityDetails.get("severity");

      // Build the vulnerability type...
      JSONObject vulnerabilityType = new JSONObject();
      vulnerabilityType.put("severity", severity);
      vulnerabilityType.put("cvssScore", cvssScore);

      // Build the note...
      note = new JSONObject();
      note.put("name", name);
      note.put("shortDescription", CVE);
      note.put("kind", "PACKAGE_VULNERABILITY");
      note.put("vulnerabilityType", vulnerabilityType);

      // Done
      return note;
    }

    void uploadOccurrenceList(JSONArray listOccurrences, String notePrefixUrl, String occurrencesUrl) throws Exception {
      for (Object o: listOccurrences) {
        JSONObject occurrence = (JSONObject) o;
        String noteUrl = notePrefixUrl + ((String) occurrence.get("noteName"));
        checkNoteForOccurrence(noteUrl, occurrence);
        createOccurrence(occurrencesUrl, occurrence);
      }
    }

    String convertDateFormat(String origDateString, SimpleDateFormat origDateFormat, SimpleDateFormat targetDateFormat) {
      String targetDateString;
      Date date;
      try {
        date = origDateFormat.parse(origDateString);
        } catch (Exception e)
        {
          log(String.format("Unable to parse the date string: '%s'", origDateString));
          return origDateString;
        }
        try {
          targetDateString = targetDateFormat.format(date);
          return targetDateString;
        }
        catch (Exception e) {
          log(String.format("Unable to convert the date string: '%s'", targetDateFormat.toPattern()));
          return origDateString;
        }
    }

    public String generateRandomChars(String candidateChars, int length) {
      StringBuilder sb = new StringBuilder();
      Random random = new Random();
      for (int i = 0; i < length; i++) {
        sb.append(candidateChars.charAt(random.nextInt(candidateChars
                .length())));
      }

      return sb.toString();
    }

    private void checkNoteForOccurrence(String noteUrl, JSONObject occurrence) throws Exception {
      log(String.format("\nChecking for Note '%s'", noteUrl));
      /* String project_notes_url = noteUrl.substring(0, noteUrl.indexOf("notes") + 5);
      log(String.format("\nChecking for notes project '%s'", project_notes_url));
      HTTPRequest checkNotesRequest = new HTTPRequest(HTTPRequest.Method.GET,new URL(project_notes_url));
      HTTPResponse checkNotesResponse = checkNotesRequest.send();
      if (!checkNotesResponse.indicatesSuccess()) {
        HTTPRequest notesRequest = new HTTPRequest(HTTPRequest.Method.POST, new URL(project_notes_url));
        notesRequest.setHeader("Content-Type", "application/json");
        HTTPResponse notesResponse = notesRequest.send();
        if (!notesResponse.indicatesSuccess()) {
          log(String.format("Failed to create notes project: '%s'", notesResponse.getContent()));
        }
      }
      log(String.format("\nChecking for Note '%s'", noteUrl));*/
      HTTPRequest checkRequest = new HTTPRequest(HTTPRequest.Method.GET, new URL(noteUrl));
      HTTPResponse checkResponse = checkRequest.send();
      if (!checkResponse.indicatesSuccess()) {
        // Create Note when not present to satisfy checks...
        JSONObject note = createNoteForOccurrence(occurrence);
        //log(String.format("Created JSON: %s", note.toJSONString()));
        int cveIndex = noteUrl.lastIndexOf('/');
        String url = (cveIndex != -1) ? noteUrl.substring(0, cveIndex) : noteUrl;
        String postQuery = String.format("%s=%s", GRAFEAS_NOTEID_QUERY_PARAM, note.get("shortDescription"));
        URL postUrl = new URL(String.format("%s?%s", url, postQuery));
        log(String.format("Creating Note '%s'", postUrl.toString()));
        HTTPRequest request = new HTTPRequest(HTTPRequest.Method.POST, postUrl);
        request.setHeader("Content-Type", "application/json");
        request.setQuery(note.toJSONString());
        HTTPResponse response = request.send();
        if (!response.indicatesSuccess())
          //Temporary work around for grafeas server running on local host, no NVD project
          throw new IOException("Failed to create Note: " + response.getContent());
          // log(String.format("Failed to create Note: '%s'", response.getContent()));
      }
    }

    private void createOccurrence(String occurrenceUrl, JSONObject occurrence) throws Exception {
      log(String.format("Creating Occurrence for '%s'", occurrence.get("resourceUrl")));
      log(String.format("Occurrence string is '%s'", occurrence.toJSONString()));
      HTTPRequest request = new HTTPRequest(HTTPRequest.Method.POST, new URL(occurrenceUrl));
      request.setHeader("Content-Type", "application/json");
      request.setQuery(occurrence.toJSONString());
      HTTPResponse response = request.send();
      if (!response.indicatesSuccess())
        throw new IOException("Failed to create Occurrence: " + response.getContent());
      JSONObject created = parseCreatedOccurrence(response.getContent());
      log("Created Occurrence: " + created.get("name"));
    }

}
