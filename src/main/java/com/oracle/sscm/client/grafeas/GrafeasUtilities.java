/**
 * Grafeas API Utilities
 * A class that utilizes the Grafeas API to create metadata in a Grafeas server.
 *
 */


package com.oracle.sscm.client.grafeas;

import io.grafeas.ApiException;
import io.grafeas.v1alpha1.GrafeasApi;
import io.grafeas.v1alpha1.model.Artifact;
import io.grafeas.v1alpha1.model.Attestation;
import io.grafeas.v1alpha1.model.AttestationAuthority;
import io.grafeas.v1alpha1.model.AttestationAuthorityHint;
import io.grafeas.v1alpha1.model.BuildDetails;
import io.grafeas.v1alpha1.model.BuildType;
import io.grafeas.v1alpha1.model.BuildProvenance;
import io.grafeas.v1alpha1.model.BuildSignature;
import io.grafeas.v1alpha1.model.BuildSignature.KeyTypeEnum;
import io.grafeas.v1alpha1.model.Command;
import io.grafeas.v1alpha1.model.FileHashes;
import io.grafeas.v1alpha1.model.Hash;
import io.grafeas.v1alpha1.model.Note;
import io.grafeas.v1alpha1.model.Occurrence;
import io.grafeas.v1alpha1.model.Empty;
import io.grafeas.v1alpha1.model.PgpSignedAttestation;
import io.grafeas.v1alpha1.model.Source;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.time.Instant;
import java.util.zip.Adler32;
import java.util.zip.CheckedInputStream;

import com.oracle.sscm.client.script.GPGScriptWrapper;

    /**
 * Utility class for creating Grafeas Build Details and Build Attestation Metadata
 */
public class GrafeasUtilities {

    private final String PROJECTS = "projects";
    private final String NOTES = "notes";
    private final String OCCURRENCES = "occurrences";
    private final String AUTHORITIES = "attestationAuthorities";
    private final String BUILDER_VERSION = "Version 0.1";
    private final String CREATE_BUILD_NOTE_OPERATION = "createBuildDetailsNote";
    private final String CREATE_AUTHORITY_NOTE_OPERATION = "createBuildAttestationAuthorityNote";
    private final String CREATE_BUILD_OCCURRENCE_OPERATION = "createBuildDetailsOccurrence";
    private final String CREATE_ATTESTATION_OCCURRENCE_OPERATION = "createBuildAttestationOccurrence";

    // Java client for Grafeas Server
    //
    private final GrafeasApi api = new GrafeasApi();

    // Project Name
    private String projectName;

    // Infrastructure Name
    private String infraName;

    // Builder version
    private String builderVersion = BUILDER_VERSION;

    // User name
    private String userName;

    // User email address
    private String userEmailAddress;

    // Build options
    private Map<String, String> buildOptions;

    // Build public key
    private String buildPublicKey;

    // Build  key id
    private String buildKeyId;

    // Build artifacts
    private List<String> buildArtifacts;

    // Source files
    private List<String> sourceFiles;

    // Build  project number
    private String projectNumber;

    // Debug boolean
    //
    private boolean debug = false;

    // Constructor - set Grafeas server URL and project name when creating utility class
    //
    public GrafeasUtilities(String urlPath, String projectName) {
        setProjectName(projectName);
        if (urlPath == null) {
            urlPath = "http://localhost:8080";
        }
        api.getApiClient().setBasePath(urlPath);
    }

    public static GrafeasUtilities getGrafeasUtilitiesWithDemoDefaults(String urlPath) {
        GrafeasUtilities utils = new GrafeasUtilities(urlPath, "weblogic-kubernetes-operator");
        utils.setInfraName("build-infrastructure");
        return utils;
    }

    /**
     * Set the project name
     */
    public void setProjectName(String projectName) {
        this.projectName = projectName;
    }

    /**
     * Get the project name
     */
    public String getProjectName() {
        return projectName;
    }

    /**
     * Set the infrastructure name
     */
    public void setInfraName(String infraName) {
        this.infraName = infraName;
    }

    /**
     * Get the infrastructure name
     */
    public String getInfraName() {
        return infraName;
    }

    /**
     * Set the builder version
     */
    public void setBuilderVersion(String builderVersion) {
        this.builderVersion = builderVersion;
    }

    /**
     * Get the builder version
     */
    public String getBuilderVersion() {
        return builderVersion;
    }

    /**
     * Set the user name
     */
    public void setUserName(String userName) {
        this.userName = userName;
    }

    /**
     * Get the user name
     */
    public String getUserName() {
        return userName;
    }

    /**
     * Set the email address
     */
    public void setUserEmailAddress(String emailAddress) {
        this.userEmailAddress = emailAddress;
    }

    /**
     * Get the email address
     */
    public String getUserEmailAddress() {
        return userEmailAddress;
    }

    /**
     * Set the build options
     */
    public void setBuildOptions(Map<String, String> buildOptions) {
        this.buildOptions = buildOptions;
    }

    /**
     * Get the build options
     */
    public Map<String,String> getBuildOptions() {
        return buildOptions;
    }


    /**
     * Set the build public key
     */
    public void setBuildPublicKey(String keyName) {
        this.buildPublicKey = keyName;
    }

    /**
     * Get the build public key
     */
    public String getBuildPublicKey() {
        return buildPublicKey;
    }

    /**
     * Set the build key id
     */
    public void setBuildKeyId(String keyId) {
        this.buildKeyId = keyId;
    }

    /**
     * Get the build key id
     */
    public String getBuildKeyId() {
        return buildKeyId;
    }

    /**
     * Set the build project number
     */
    public void setProjectNumber(String projectNum) {
        this.projectNumber = projectNum;
    }

    /**
     * Get the build project number
     */
    public String getProjectNumber() {
        return projectNumber;
    }

    /**
     * Set the build artifacts files
     */
    public void setBuildArtifacts(List<String> buildArtifacts) {
        this.buildArtifacts = buildArtifacts;
    }

    /**
     * Get the build artifacts
     */
    public List<String> getBuildArtifacts() {
        return buildArtifacts;
    }

    /**
     * Set the source files
     */
    public void setSourceFiles(List<String> sourceFiles) {
        this.sourceFiles = sourceFiles;
    }

    /**
     * Get the source files
     */
    public List<String> getSourceFiles() {
        return sourceFiles;
    }

    /**
     * Enable debugging
     */
    public void enableDebugging() {
        debug = true;
        api.getApiClient().setDebugging(true);
    }

    /**
     * Create a build details note metadata.
     *
     * @throws ApiException if the Api call fails
     **/
    public void createBuildDetailsNote(String name, String shortDesc, String longDesc) throws ApiException {
        log("Creating build detail note for name: " + name);

        Note note = new Note();
        note.setName(getNoteName(infraName, name));
        note.setKind(Note.KindEnum.BUILD_DETAILS);
        note.setShortDescription(shortDesc);
        note.setLongDescription(longDesc);
        note.setBuildType(createBuildType());
        note.setCreateTime(getCurrenttime());
        note.setOperationName(CREATE_BUILD_NOTE_OPERATION);

        Note createdNote = api.createNote(getInfraName(), name, note);

        log("Created note: " + createdNote);
    }

    /**
     * Return true if build details metadata note already exists, false otherwise.
     *
     * @throws ApiException if the Api call fails
     **/
    public boolean doesBuildDetailsNoteExist(String name) {

        boolean fnd = false;
        try {
            Note note = api.getNote(getInfraName(), name);
            log("doesBuildDetailsNoteExist: note " + note);
            fnd = true;
        } catch (ApiException e) {
            fnd = false;
            logException(e);
        }

        return fnd;
    }

    /**
     * Deletes the given build details note from the server.
     */
    public void deleteBuildDetailsNote(String name) throws ApiException {
        String projectsId = getProjectName();
        Empty response = api.deleteNote(projectsId, name);

        log("Deleted build details note name: " + name);
    }

    /**
     * Create a build details occurrence metadata entry.
     *
     * @throws ApiException if the Api call fails
     **/
    public void createBuildDetailsOccurrence(String occurrenceName, String occurrenceUrl, String noteName) throws ApiException {

        log("Create occurrence name = " + occurrenceName);

        Occurrence occurrence = new Occurrence();
        occurrence.setName(getOccurrenceName(projectName, occurrenceName));
        occurrence.setResourceUrl(occurrenceUrl);
        occurrence.setNoteName(getNoteName(infraName, noteName));
        occurrence.setKind(Occurrence.KindEnum.BUILD_DETAILS);
        occurrence.setCreateTime(getCurrenttime());
        occurrence.setOperationName(CREATE_BUILD_OCCURRENCE_OPERATION);

        occurrence.setBuildDetails(createBuildDetails(getBuildArtifacts()));

        Occurrence createdOccurrence = api.createOccurrence(getProjectName(), occurrence);

        log("Created occurrence = " + createdOccurrence);
    }

    /**
     * Create a build details occurrence metadata entry.
     *
     * @throws ApiException if the Api call fails
     **/
    public boolean doesBuildDetailsOccurrenceExist(String occurrenceName) throws ApiException {

        boolean fnd = false;
        try {
            Occurrence occurrence = api.getOccurrence(getProjectName(), occurrenceName);
            log("doesBuildDetailsOccurrenceExist: occurrence = " + occurrence);
            fnd = true;
        } catch (ApiException e) {
            fnd = false;
            logException(e);
        }

        return fnd;
    }

    /**
     * Creates a new attestation authority note.
     *
     * @throws ApiException if the Api call fails
     */
    public void createAttestationAuthorityNote(String name, String shortDesc, String longDesc) throws ApiException {

        log("Create attestation authority name = " + name);

        Note note = new Note();
        note.setName(getNoteName(getInfraName(), name));
        note.setKind(Note.KindEnum.ATTESTATION_AUTHORITY);
        note.setShortDescription(shortDesc);
        note.setLongDescription(longDesc);
        note.setAttestationAuthority(createAuthority(name));
        note.setCreateTime(getCurrenttime());
        note.setOperationName(CREATE_AUTHORITY_NOTE_OPERATION);

        Note createdNote = api.createNote(getProjectName(), name, note);

        log("Created attestation authority note = " + createdNote);
    }

    /**
     * Creates a new test attestation authority note.
     *
     * @throws ApiException if the Api call fails
     */
    /*
    public void createTestAttestationAuthorityNote(String name, String shortDesc, String longDesc) throws ApiException {

        log("Create attestation authority name = " + name);

        Note note = new Note();
        note.setName(getNoteName(getInfraName(), name));
        note.setKind(Note.KindEnum.ATTESTATION_AUTHORITY);
        note.setShortDescription(shortDesc);
        note.setLongDescription(longDesc);
        note.setAttestationAuthority(createAuthority(name));
        note.setCreateTime(getCurrenttime());
        //note.setOperationName(CREATE_AUTHORITY_NOTE_OPERATION);

        Note createdNote = api.createNote(getProjectName(), name, note);

        log("Created test attestation authority note = " + createdNote);
    }
    */

    /**
     * Return true if build attestation metadata note already exists, false otherwise.
     *
     * @throws ApiException if the Api call fails
     **/
    public boolean doesAttestationAuthorityNoteExist(String name) {
        boolean fnd = false;
        try {
            Note note = api.getNote(getInfraName(), name);
            log("doesAttestationAuthorityNoteExist: note " + note);
            if (note.getKind() == Note.KindEnum.ATTESTATION_AUTHORITY) {
                fnd = true;
            }
        } catch (ApiException e) {
            fnd = false;
            logException(e);
        }

        return fnd;
    }

    /**
     * Deletes the given attestation authority note from the system.
     *
     * @throws ApiException if the Api call fails
     */
    public void deleteAttestationAuthorityNote(String authorityName) throws ApiException {
        Empty response = api.deleteNote(getProjectName(), authorityName);

        log("Deleted attestation authority note " + authorityName);
    }

    /**
     * Creates a new Attestation Authority occurrence.
     *
     * @throws ApiException if the Api call fails
     */
    public void createAttestationOccurrence(String authorityName, String resourceUrl) throws ApiException, IOException {

        Occurrence occurrence = new Occurrence();
        occurrence.setName(getOccurrenceName(projectName, authorityName + "Attestation-" + System.currentTimeMillis()));
        occurrence.setResourceUrl(resourceUrl);
        occurrence.setNoteName(getNoteName(infraName, authorityName + "AttestationAuthority"));
        occurrence.setKind(Occurrence.KindEnum.ATTESTATION_AUTHORITY);

        occurrence.setCreateTime(getCurrenttime());
        occurrence.setOperationName(CREATE_ATTESTATION_OCCURRENCE_OPERATION);

        occurrence.setAttestation(createSignedAttestation(getAuthorityName(authorityName), resourceUrl));

        Occurrence createdAttestationOccurrence = api.createOccurrence(getProjectName(), occurrence);

        log("Created attestation occurrence  = " + createdAttestationOccurrence);
    }

    /**
     * Creates a new Attestation Authority occurrence.
     *
     * @throws ApiException if the Api call fails
     */
    public boolean doesAttestationOccurrenceExist(String occurrenceName) throws ApiException {

        boolean fnd = false;
        try {
            Occurrence occurrence = api.getOccurrence(getProjectName(), occurrenceName);
            log("doesAttestationOccurrenceExist = " + occurrence);
            if (occurrence.getAttestation() != null) {
                fnd = true;
            }
        } catch (ApiException e) {
            fnd = false;
            logException(e);
        }

        return fnd;
    }

    /**
     * Deletes the given occurrence from the system.
     *
     * @throws ApiException if the Api call fails
     */
    public void deleteOccurrence(String name) throws ApiException {

        Empty occurrence = api.deleteOccurrence(getProjectName(), name);
        log("Deleted occurrence " + name + " " + occurrence);
    }


    // Create a build type with build version and build signature
    //
    private BuildType createBuildType() {

        BuildSignature bldSig = new BuildSignature();

        if (buildPublicKey != null) {
            bldSig.setPublicKey(getBuildPublicKey());
            bldSig.setKeyType(KeyTypeEnum.PGP_ASCII_ARMORED);

            // Calculate signature using inline key - TBD
            bldSig.setSignature("XXXYYYZZZ");
        }

        if (buildKeyId != null) {
            bldSig.setKeyId(getBuildKeyId());
            bldSig.setKeyType(KeyTypeEnum.PGP_ASCII_ARMORED);

            // Calculate signature using key id - TBD
            bldSig.setSignature("XXXYYYZZZ");
        }


        BuildType bldType = new BuildType();
        bldType.setBuilderVersion(getBuilderVersion());

        if (buildKeyId != null || buildPublicKey != null) {
            bldType.setSignature(bldSig);
        }

        return bldType;
    }

    // Return the current time
    //
    private String getCurrenttime() {
        Instant date = Instant.now();
        return date.toString();
    }

    // Create a build details with info.
    //
    private BuildDetails createBuildDetails(List<String> files) throws ApiException {

        BuildProvenance bldProv = new BuildProvenance();
        bldProv.setId("" + System.currentTimeMillis());
        bldProv.setProjectId(getProjectName());
        if (projectNumber != null) {
            bldProv.setProjectNum(projectNumber);
        }

        //bldProv.setCommands(getDefaultCommands());
        if (files != null) {
            bldProv.setBuiltArtifacts(getArtifacts(files));
        }

        bldProv.setCreateTime(getCurrenttime());
        bldProv.setStartTime(getCurrenttime());
        bldProv.setFinishTime(getCurrenttime());

        if (userName != null) {
            bldProv.setUserId(userName);
        }

        if (userEmailAddress != null) {
            bldProv.setCreator(userEmailAddress);
        }

        if (sourceFiles != null) {
            bldProv.setSourceProvenance(getSource());
        }

        if (getBuildOptions() != null) {
            bldProv.setBuildOptions(getBuildOptions());
        }

        bldProv.setBuilderVersion(getBuilderVersion());

        BuildDetails bldDetails = new BuildDetails();
        bldDetails.setProvenance(bldProv);
        bldDetails.setProvenanceBytes(bldProv.toString());

        return bldDetails;
    }

    // Return set of commands for the build
    //
    private List<Command> getDefaultCommands() {
        List<String> envs = new ArrayList<String>();
        envs.add("Env1");
        envs.add("Env2");

        List<String> args = new ArrayList<String>();
        args.add("arg1");
        args.add("arg2");

        List<Command> cmds = new ArrayList<Command>();
        Command cmd = new Command();
        cmd.setName("bldJar");
        cmd.setEnv(envs);
        cmd.setArgs(args);
        cmd.setDir("/user/pbower");
        cmd.setId("123");
        cmds.add(cmd);

        // Second command
        cmd = new Command();
        cmd.setName("javac");
        cmd.setEnv(envs);
        cmd.setArgs(args);
        cmd.setDir("/user/jones");
        cmd.setId("456");
        cmds.add(cmd);

        return cmds;

    }

    // Return set of artifacts for the build
    //
    private List<Artifact> getArtifacts(List<String> files) throws ApiException {

        List<Artifact> artifacts = new ArrayList<Artifact>();
        for (String fileStr : files) {
            Artifact artifact = new Artifact();
            File file = new File(fileStr);

            String checksum = createChecksumForFile(fileStr);
            artifact.setChecksum(checksum);

            artifact.setId(file.toURI().toString());

            List<String> names = new ArrayList<String>();
            names.add(file.toURI().toString());
            artifact.setNames(names);

            artifacts.add(artifact);

        }


        return artifacts;
    }

    // Return source for the build
    //
    private Source getSource() {
        Source src = new Source();

        Map<String, FileHashes> fileHashesMap = new HashMap<String, FileHashes>();

        for (String sourceFile : sourceFiles) {
            List<Hash> hashes = new ArrayList<Hash>();
            Hash hash = new Hash();

            hash.setType(Hash.TypeEnum.SHA256);
            hash.setValue(createHashForFile(sourceFile));

            // Add to list Of Hash
            hashes.add(hash);

            FileHashes fileHashes = new FileHashes();
            fileHashes.setFileHash(hashes);


            fileHashesMap.put(sourceFile, fileHashes);
        }

        src.setFileHashes(fileHashesMap);

        return src;
    }

    // Return Attestation Authority
    //
    private AttestationAuthority createAuthority(String name) {
        AttestationAuthorityHint hint = new AttestationAuthorityHint();
        hint.setHumanReadableName(name);

        AttestationAuthority auth = new AttestationAuthority();
        auth.setHint(hint);

        return auth;
    }

    // Return Attestation
    //
    private Attestation createSignedAttestation(String authorityName, String resourceUrl) throws IOException {
        PgpSignedAttestation signedAttest = new PgpSignedAttestation();

        GPGScriptWrapper gpg = new GPGScriptWrapper();

        String signedData = GPGScriptWrapper.sign(authorityName, resourceUrl);
        String key = GPGScriptWrapper.getKeyID(signedData);

        if (signedData == null || key == null) {
            throw new IllegalStateException("Null signedData or key!");
        }

        // Create signature with key id
        signedAttest.setSignature(signedData);
        signedAttest.setContentType(PgpSignedAttestation.ContentTypeEnum.CONTENT_TYPE_UNSPECIFIED);
        signedAttest.setPgpKeyId(key);

        Attestation attest = new Attestation();
        attest.setPgpSignedAttestation(signedAttest);

        return attest;
    }

    // Get projects prefix - projects/<project name>
    private String getProjectPrefix(String name) {
        return PROJECTS + "/" + name;
    }

    // Get projects prefix - projects/<infra name>
    private String getInfraPrefix() {
        return PROJECTS + "/" + getInfraName();
    }

    // Get note name - projects/<project name>/notes/<note name>
    //
    private String getNoteName(String project, String name) {
        return getProjectPrefix(project) + "/" + NOTES + "/" + name;
    }

    // Get occurrence name - projects/<project name>/occurrences/<occurrence name>
    //
    private String getOccurrenceName(String project, String name) {
        return getProjectPrefix(project) + "/" + OCCURRENCES + "/" + name;
    }

    // Get authority name - projects/<project name>/attestationAuthorities/<authority name>
    //
    private String getAuthorityName(String name) {
        return getProjectPrefix(getInfraName()) + "/" + AUTHORITIES + "/" + name;
    }

    // Create a checksum for a file using a message digest.
    //
    private String createChecksumForFile(String filename) {

        long versionNumber = 0;
        CheckedInputStream cis = null;
        try {
            // Compute checksum for file using Adler32
            cis = new CheckedInputStream(new FileInputStream(filename), new Adler32());
            byte[] tempBuf = new byte[128];
            while (cis.read(tempBuf) >= 0) {
            }
            versionNumber = cis.getChecksum().getValue();
        } catch (IOException ignore) {
        } finally {
            if (cis != null)
                try {
                    cis.close();
                } catch (IOException ignore) {}
        }

        String versionString = (new Long(versionNumber)).toString();
        return versionString;
    }

    // Create a checksum for a file using a message digest.
    //
    public static byte[] createHashForFile(String filename) {

        try {
            InputStream fis = new FileInputStream(filename);

            byte[] buffer = new byte[1024];
            MessageDigest complete = MessageDigest.getInstance("SHA2");
            int numRead;
            do {
                numRead = fis.read(buffer);
                if (numRead > 0) {
                    complete.update(buffer, 0, numRead);
                }
            } while (numRead != -1);
            fis.close();
            return complete.digest();
        } catch (Exception e) {
            return null;
        }
    }

    // Log debug output
    //
    private void log(String msg) {
        if (debug) {
            System.out.println(msg);
        }
    }

    // Log the fields in an ApiException
    //
    private void logException(ApiException e) {
        if (!debug)
            return;

        log("ApiException: msg = " + e);
        log("ApiException: code = " + e.getCode());
        log("ApiException: hdrs = " + e.getResponseHeaders());
        log("ApiException: bdy = " + e.getResponseBody());
    }

}
