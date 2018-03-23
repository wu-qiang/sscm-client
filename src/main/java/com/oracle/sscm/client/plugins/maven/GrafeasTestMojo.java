package com.oracle.sscm.client.plugins.maven;

import io.grafeas.v1alpha1.model.Attestation;
import io.grafeas.v1alpha1.model.PgpSignedAttestation;
import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

import java.io.IOException;
import java.net.URL;

import com.nimbusds.oauth2.sdk.http.HTTPRequest;
import com.nimbusds.oauth2.sdk.http.HTTPResponse;

import net.minidev.json.JSONObject;
import net.minidev.json.parser.JSONParser;

import com.oracle.sscm.client.script.GPGScriptWrapper;

@Mojo(name = "testAttestation")
public class GrafeasTestMojo extends AbstractMojo {

    @Parameter(property = "testAttestation.projectId")
    private String projectId;

    @Parameter(property = "testAttestation.grafeasUrl")
    private String grafeasUrl;

    @Parameter(property = "testAttestation.resourceUrl")
    private String resourceUrl;

    private String noteName;
    private String grafeasOccurrence;

    //
    // Default values for Grafeas Notes and Occurrences for test:
    //  - <URL>/v1alpha1/projects/{projectId}/notes/qa
    //  - <URL>/v1alpha1/projects/{projectId}/occurrences
    //
    public static final String URL_SLASH = "/";
    public static final String GRAFEAS_VERSION = "v1alpha1/";
    public static final String GRAFEAS_PROJECTS = "projects/";
    public static final String GRAFEAS_NOTEID_QUERY_PARAM = "noteId";
    public static final String GRAFEAS_NOTE_NAME_PREFIX = GRAFEAS_VERSION;
    public static final String GRAFEAS_PROJECTS_PREFIX = GRAFEAS_VERSION + GRAFEAS_PROJECTS;
    public static final String GRAFEAS_NOTE_NAME = GRAFEAS_PROJECTS + "build-infrastructure/notes/qa";
    public static final String GRAFEAS_NOTES = GRAFEAS_PROJECTS_PREFIX + "%s/notes";
    public static final String GRAFEAS_OCCURRENCES = GRAFEAS_PROJECTS_PREFIX + "%s/occurrences";

    private void log(String msg) {
      getLog().info(msg);
    }

  public void execute() throws MojoExecutionException {

      System.out.println("GrafeasUrl = " + grafeasUrl);
      System.out.println("projectId = " + projectId);
      System.out.println("resourceUrl = " + resourceUrl);

      // Location of Grafeas API server
      if (!grafeasUrl.equals("UNKNOWN")) {
        if (!grafeasUrl.endsWith(URL_SLASH)) grafeasUrl += URL_SLASH;
      }

      //noteName = String.format(GRAFEAS_NOTE_NAME, projectId);
      noteName = GRAFEAS_NOTE_NAME;
      grafeasOccurrence = String.format(GRAFEAS_OCCURRENCES, projectId);

      try {

         JSONObject occurrence = createAttestationOccurrence(); 
         log(String.format("grafeas occurrences = " + grafeasOccurrence));
         checkQAAttestationAuthorityNote(occurrence); 
         String grafeasUrlOccurrences = grafeasUrl + grafeasOccurrence;
         log(String.format("grafeasURl Occurrence  =  '%s'", grafeasUrlOccurrences));
         uploadAttestationOccurrence(grafeasUrlOccurrences, occurrence);
      } catch (Exception ex) {
         log("Exception = " + ex.toString());
         ex.printStackTrace();
      }
  }

  /*
    Creating Test attestation Occurrence JSON
    QA occurrence should look like  -
    {
      "resourceUrl": "$(cat image-digest.txt)",
      "noteName": "projects/{projectId}/notes/qa",
      "attestation": {
         "pgpSignedAttestation": {
           "signature": "$(signature)",
           "contentType": "application/vnd.gcr.image.url.v1",
           "pgpKeyId": "${GPG_KEY_ID}"
         }
       }
    }
  */
  private JSONObject createAttestationOccurrence() throws Exception {
      log(String.format("Creating Occurrence"));
      JSONObject occurrence = new JSONObject();
      //occurrence.put("createTime", getCurrenttime());
      occurrence.put("noteName", noteName);
      occurrence.put("resourceUrl", resourceUrl);
      String occurrenceName = "QATested" + System.currentTimeMillis();
      occurrence.put("name", "projects/" + projectId + "/occurrences/" + occurrenceName);
      occurrence.put("attestation", createAttestation(resourceUrl).toString());
      System.out.println("occurrence = " + occurrence);
      return occurrence;
  }

  private Attestation createAttestation(String data) throws IOException {

        PgpSignedAttestation signedAttest = new PgpSignedAttestation();
        GPGScriptWrapper gpg = new GPGScriptWrapper();

        String signedData = gpg.sign(data);
        String key = gpg.getKeyID(signedData);

        if (signedData != null && key != null) {

            // Create signature with key id
            signedAttest.setSignature(signedData);
            signedAttest.setContentType(PgpSignedAttestation.ContentTypeEnum.SIMPLE_SIGNING_JSON);

            signedAttest.setPgpKeyId(key);
        }

        Attestation attest = new Attestation();
        attest.setPgpSignedAttestation(signedAttest);

        return attest;
  }

  private void uploadAttestationOccurrence(String occurrenceUrl, JSONObject occurrence) throws Exception {
      log(String.format("Uploading Occurrence for '%s'", occurrence.get("resourceUrl")));
      HTTPRequest request = new HTTPRequest(HTTPRequest.Method.POST, new URL(occurrenceUrl));
      request.setHeader("Content-Type", "application/json");
      request.setQuery(occurrence.toJSONString());
      HTTPResponse response = request.send();
      if (!response.indicatesSuccess())
        throw new IOException("Failed to create Occurrence: " + response.getContent());
      JSONObject created = parseCreatedOccurrence(response.getContent());
      log("Created Occurrence: " + created.get("name"));
      log("occurrence: " + created);
  }

  private JSONObject parseCreatedOccurrence(String json) throws Exception {
     JSONParser parser = new JSONParser(JSONParser.USE_HI_PRECISION_FLOAT | JSONParser.ACCEPT_TAILLING_SPACE);
     Object object = parser.parse(json);
     if (!(object instanceof JSONObject)) {
        log("Unable to read occurrence JSON: " + json);
        throw new IOException("Unable to parse JSON: " + json);
     }
     return (JSONObject) object;
  }



  /* 
   *  Check to see if there is a QA note already present. If not, add one
   */

  private void checkQAAttestationAuthorityNote(JSONObject occurrence) throws Exception {
      log(String.format("\nChecking for Note '%s'", noteName));
      HTTPRequest checkRequest = new HTTPRequest(HTTPRequest.Method.GET, new URL(grafeasUrl + GRAFEAS_VERSION + noteName));
      HTTPResponse checkResponse = checkRequest.send();
      log(String.format("\nHTTPResponse = '%s'", checkResponse.getContent()));
      if (!checkResponse.indicatesSuccess()) {
        // Create Note when not present to satisfy checks...
        JSONObject note = createQAAttestationAuthorityNote();
        log(String.format("Created JSON: %s", note.toJSONString()));

        String postQuery = String.format("%s=%s", GRAFEAS_NOTEID_QUERY_PARAM, "qa");
        String grafeasNotes = String.format(GRAFEAS_NOTES, projectId);
        log("GRAFEAS_NOTES = " + grafeasNotes);
        URL postUrl = new URL(String.format(grafeasUrl + "%s?%s", grafeasNotes, postQuery));
        log(String.format("Creating Note '%s'", postUrl.toString()));
        HTTPRequest request = new HTTPRequest(HTTPRequest.Method.POST, postUrl);
        request.setHeader("Content-Type", "application/json");
        request.setQuery(note.toJSONString());
        HTTPResponse response = request.send();
        if (!response.indicatesSuccess())
          throw new IOException("Failed to create Note: " + response.getContent());
      }
  }

  /*
   * Create a qa attestation note 
   */

  private JSONObject createQAAttestationAuthorityNote() {
      JSONObject note = null;

      // Build the attestation authority ...
      JSONObject attestationAuthority= new JSONObject();
      JSONObject attestationAuthorityHint= new JSONObject();
      attestationAuthorityHint.put("humanReadableName", "QA");
      attestationAuthority.put("hint", attestationAuthorityHint);

      // Build the note...
      note = new JSONObject();
      note.put("name", noteName);
      note.put("shortDescription", "QA image signer");
      note.put("longDescription", "QA image signer");
      note.put("attestationAuthorityDetails", attestationAuthority);

      // Done
      return note;
  }

}
