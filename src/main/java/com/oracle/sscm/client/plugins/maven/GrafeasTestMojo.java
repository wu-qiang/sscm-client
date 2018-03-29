package com.oracle.sscm.client.plugins.maven;

import com.oracle.sscm.client.grafeas.GrafeasUtilities;
import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

@Mojo(name = "testAttestation")
public class GrafeasTestMojo extends AbstractMojo {

    @Parameter(property = "testAttestation.projectName", defaultValue = "UNKNOWN")
    private String projectName;

    @Parameter(property = "testAttestation.grafeasUrl", defaultValue = "UNKNOWN")
    private String grafeasUrl;

    @Parameter(property = "testAttestation.resourceUrl", defaultValue = "UNKNOWN")
    private String resourceUrl;

    @Parameter(property = "testAttestation.authorityName", defaultValue = "Test")
    private String authorityName;

    @Parameter(property = "testAttestation.debugLog", defaultValue = "true")
    private String debugLog;

    private String grafeasOccurrence;

    //
    // Default values for Grafeas Notes and Occurrences for test:
    //  - <URL>/v1alpha1/projects/build-infrastructure/notes/TestAttestationAuthority
    //  - <URL>/v1alpha1/projects/{projectName}/occurrences
    //

    public static final String URL_SLASH = "/";

    private void log(String msg) {
      getLog().info(msg);
    }

    public void execute() throws MojoExecutionException {

        System.out.println("GrafeasUrl = " + grafeasUrl);
        System.out.println("projectName = " + projectName);
        System.out.println("resourceUrl = " + resourceUrl);
        System.out.println("authorityName = " + authorityName);

        try {
            // Setup arguments from parameters...
            GrafeasUtilities utils = getUtils();

            log("\nCreating test Attestation Occurrence.");

            utils.createAttestationOccurrence(authorityName, resourceUrl);
            log("\nGenerated Test Attestation.");
      } catch (Exception ex) {
         log("Exception = " + ex.toString());
         ex.printStackTrace();
      }
    }

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

        GrafeasUtilities utils = GrafeasUtilities.getGrafeasUtilitiesWithDemoDefaults(grafeasUrl);

        if ("true".equals(debugLog))
            utils.enableDebugging();

        return utils;

    }
}
