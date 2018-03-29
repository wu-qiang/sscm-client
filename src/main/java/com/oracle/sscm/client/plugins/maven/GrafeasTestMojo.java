package com.oracle.sscm.client.plugins.maven;

import com.oracle.sscm.client.grafeas.GrafeasUtilities;
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

    @Parameter(property = "testAttestation.infraName", defaultValue = "build-infrastructure")
    private String infraName;

    @Parameter(property = "testAttestation.authorityName", defaultValue = "qa")
    private String authorityName;

    @Parameter(property = "testAttestation.debugLog", defaultValue = "true")
    private String debugLog;

    private String noteName;
    private String grafeasOccurrence;

    //
    // Default values for Grafeas Notes and Occurrences for test:
    //  - <URL>/v1alpha1/projects/build-infrastructure/notes/qa
    //  - <URL>/v1alpha1/projects/{projectId}/occurrences
    //

    public static final String URL_SLASH = "/";

    private void log(String msg) {
      getLog().info(msg);
    }

    public void execute() throws MojoExecutionException {

        System.out.println("GrafeasUrl = " + grafeasUrl);
        System.out.println("projectId = " + projectId);
        System.out.println("resourceUrl = " + resourceUrl);

        try {
            // Setup arguments from parameters...
            GrafeasUtilities utils = getUtils();

            log("\nCreating test Attestation Metadata.");

            if (!utils.doesAttestationAuthorityNoteExist(authorityName)) {
                String desc = infraName + ":" + authorityName;
                utils.createTestAttestationAuthorityNote(authorityName, desc, desc);
                log("\nCreated Test Attestation Note Metadata.");
            }

            String uniqueId = authorityName + System.currentTimeMillis();
            utils.createTestAttestationOccurrence(uniqueId, resourceUrl, authorityName);
            log("\nGenerated Test Attestation.");
      } catch (Exception ex) {
         log("Exception = " + ex.toString());
         ex.printStackTrace();
      }
    }

    public String getInfraName() { return infraName; }

    public void setInfraName(String infraName) { this.infraName = infraName; }

    public String getAuthorityName() { return authorityName; }

    public void setAuthorityName(String authorityName) { this.authorityName = authorityName; }

    public String getProjectName() { return projectId; }

    public void setProjectName(String projectId) { this.projectId = projectId; }

    private GrafeasUtilities getUtils() {

        // Location of Grafeas API server
        if (grafeasUrl != null && !grafeasUrl.equals("UNKNOWN")) {
            if (grafeasUrl != null && grafeasUrl.endsWith(URL_SLASH)) {
                grafeasUrl = grafeasUrl.substring(0, grafeasUrl.length() - 1);
            }
            if (grafeasUrl.equals("http://:")) {
                grafeasUrl = null;
            }
        }

        GrafeasUtilities utils = new GrafeasUtilities(grafeasUrl, projectId);

        if ("true".equals(debugLog))
            utils.enableDebugging();

        utils.setInfraName(infraName);
        return utils;

    }
}
