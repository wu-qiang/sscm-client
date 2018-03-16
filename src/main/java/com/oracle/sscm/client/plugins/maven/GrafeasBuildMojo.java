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
import java.util.List;
import java.util.Map;

import com.oracle.sscm.client.grafeas.GrafeasUtilities;

@Mojo(name = "buildDetails")
public class GrafeasBuildMojo extends AbstractMojo {

    private static final String URL_SLASH = "/";

    private boolean debug = true;

    @Parameter(property = "buildDetails.grafeasUrl", defaultValue = "UNKNOWN")
    private String grafeasUrl;

    @Parameter(property = "buildDetails.projectName")
    private String projectName;

    @Parameter(property = "buildDetails.authorityName")
    private String authorityName;

    @Parameter(property = "buildDetails.builderName")
    private String builderName;

    @Parameter(property = "buildDetails.builderDescription")
    private String builderDescription;

    @Parameter(property = "buildDetails.builderVersion")
    private String builderVersion;

    @Parameter(property = "buildDetails.resourceUrl")
    private String resourceUrl;

    @Parameter(property = "buildDetails.userName")
    private String userName;

    @Parameter(property = "buildDetails.userEmailAddress")
    private String userEmailAddress;

    @Parameter(property = "buildDetails.buildOptions")
    private Map<String, String> buildOptions;

    @Parameter(property = "buildDetails.buildPublicKey")
    private String buildPublicKey;

    @Parameter(property = "buildDetails.buildKeyId")
    private String buildKeyId;

    @Parameter(property = "buildDetails.buildArtifacts")
    private List<String> buildArtifacts;

    @Parameter(property = "buildDetails.sourceFiles")
    private List<String> sourceFiles;

    @Parameter(property = "buildDetails.projectNumber")
    private String projectNumber;



    private void log(String msg) {
      getLog().info(msg);
    }

    public void execute() throws MojoExecutionException {

        try {
            log("\nCreating Build Details Occurrences Metadata.");

            // Setup arguments from parameters...
            GrafeasUtilities utils = getUtils(false);
            if (!utils.doesBuildDetailsNoteExist(builderName)) {
                utils.createBuildDetailsNote(builderName, projectName + "-" + builderName, builderDescription);
                log("\nCreated Build Details Note Metadata.");
            }
            String uniqueId = builderName + System.currentTimeMillis();
            utils.createBuildDetailsOccurrence(uniqueId, resourceUrl, builderName);
            log("\nCreated Build Details Occurrences Metadata.");

            log("\nCreating Build Attestation Metadata.");

            // Setup arguments from parameters...
            utils = getUtils(true);

            if (!utils.doesAttestationAuthorityNoteExist(authorityName)) {
                utils.createAttestationAuthorityNote(authorityName, projectName + ":" + authorityName, builderDescription);
                log("\nCreated Build Attestation Note Metadata.");
            }
            uniqueId = authorityName + System.currentTimeMillis();
            utils.createAttestationOccurrence(uniqueId, resourceUrl, authorityName);
            log("\nGenerated Build Attestation.");
        } catch (Exception e) {
            throw new MojoExecutionException("Error loading build metatdata into grafeas", e);
        }

    }

    public String getGrafeasUrl() {
        return grafeasUrl;
    }

    public void setGrafeasUrl(String grafeasUrl) {
        this.grafeasUrl = grafeasUrl;
    }

    public String getProjectName() {
        return projectName;
    }

    public void setProjectName(String projectName) {
        this.projectName = projectName;
    }

    public String getAuthorityName() {
        return authorityName;
    }

    public void setAuthorityName(String authorityName) {
        this.authorityName = authorityName;
    }

    public String getBuilderName() {
        return builderName;
    }

    public void setBuilderName(String builderName) {
        this.builderName = builderName;
    }

    public String getBuilderDescription() {
        return builderDescription;
    }

    public void setBuilderDescription(String builderDescription) {
        this.builderDescription = builderDescription;
    }


    public String getBuilderVersion() {
        return builderVersion;
    }

    public void setBuilderVersion(String builderVersion) {
        this.builderVersion = builderVersion;
    }

    public String getResourceUrl() {
        return resourceUrl;
    }

    public void setResourceUrl(String resourceUrl) {
        this.resourceUrl = resourceUrl;
    }

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public String getUserEmailAddress() {
        return userEmailAddress;
    }

    public void setUserEmailAddress(String emailAddress) {
        this.userEmailAddress = emailAddress;
    }

    public Map<String,String> getBuildOptions() {
        return buildOptions;
    }

    public void setBuildOptions(Map<String, String> buildOptions) {
        this.buildOptions = buildOptions;
    }

    public String getBuildPublicKey() {
        return buildPublicKey;
    }

    public void setBuildPublicKey(String keyName) {
        this.buildPublicKey = keyName;
    }

    public String getBuildKeyId() {
        return buildKeyId;
    }

    public void setBuildKeyId(String keyId) {
        this.buildKeyId = keyId;
    }

    public String getProjectNumber() {
        return projectNumber;
    }

    public void setProjectNumber(String projectNum) {
        this.projectNumber = projectNum;
    }

    public void setBuildArtifacts(List<String> artifacts) {
        this.buildArtifacts = artifacts;
    }

    public List<String> getBuildArtifacts() {
        return buildArtifacts;
    }

    public void setSourceFiles(List<String> sourceFiles) {
        this.sourceFiles = sourceFiles;
    }

    public List<String> getSourceFiles() {
        return sourceFiles;
    }

    private GrafeasUtilities getUtils(boolean isAttestation) {

        // Location of Grafeas API server
        if (grafeasUrl != null && !grafeasUrl.equals("UNKNOWN")) {
            if (grafeasUrl != null && grafeasUrl.endsWith(URL_SLASH)) {
                grafeasUrl = grafeasUrl.substring(0, grafeasUrl.length() - 1);
            }
            if (grafeasUrl.equals("http://:")) {
                 grafeasUrl = null;
            }
        }

        GrafeasUtilities utils = new GrafeasUtilities(grafeasUrl, projectName);

        if (debug)
            utils.enableDebugging();

        if (builderVersion != null) {
            utils.setBuilderVersion(builderVersion);
        }

        utils.setUserName(userName);
        utils.setUserEmailAddress(userEmailAddress);
        utils.setBuildKeyId(buildKeyId);
        utils.setProjectNumber(projectNumber);
        utils.setBuildArtifacts(buildArtifacts);
        utils.setSourceFiles(sourceFiles);

        return utils;

    }

}
