package com.oracle.sscm.client.script;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Wrapper class to invoke the GPG_SCRIPT for signing and verifying signatures
 * This GPG_SCRIPT calls the OS gpg command
 */
public class GPGScriptWrapper {
  private String script;
  private String gpgAuthorityName;

  private static final String SIGN = "--sign";
  private static final String VERIFY = "--verify";
  private static final String GET_KEY_ID = "--get-signature-keyid";
  private static final String GET_DATA = "--get-signature-data";
  private static final String INIT_KEYRING = "--init-keyring";

  private static final String GPG_SCRIPT_ENV_VAR = "GPG_SCRIPT";
  private static final String GPG_AUTHORITY_NAME_ENV_VAR = "GPG_AUTHORITY_NAME";

  /**
   * Use the GPG_SCRIPT, GPG_AUTHORITY_NAME environment variables defined in the Wercker pipeline
   */
  public GPGScriptWrapper() {
    script = System.getenv(GPG_SCRIPT_ENV_VAR);
    gpgAuthorityName = System.getenv(GPG_AUTHORITY_NAME_ENV_VAR);
    initKeyRing();
  }

  /**
   *
   * @param script full path of the GPG script.  Should be under GPG_SCRIPT Wercker env variable
   * @param gpgAuthorityName full name of an attestation authority
   */
  public GPGScriptWrapper(String script, String gpgAuthorityName) {
    this.script = script;
    this.gpgAuthorityName = gpgAuthorityName;
    initKeyRing();
  }


  /**
   *
   * @return true if the key ring is initialized successfully, false otherwise.
   */
  public boolean initKeyRing() {
    boolean initialized = false;
    int exitCode = 1;
    try {
      exitCode = getExitCodeOfExecScript(new String[]{script, INIT_KEYRING});
    } catch(IOException ioe) {

    }

    return exitCode == 0;
  }

  /**
   *
   * @param data data to be signed
   * @return  Base64 encoding of the signature
   */
  public String sign(String data) throws IOException {
    return execScript(new String[] {script, SIGN, gpgAuthorityName, data});
  }


  /**
   * Verify the base64 encoded signature
   * @param encodedSignature  base64 encoded signature
   * @return  true if the signature is valid, false otherwise
   */
  public boolean verify(String encodedSignature) throws IOException {
    return  getExitCodeOfExecScript(new String[] {script, VERIFY, encodedSignature}) == 0;
  }


  /**
   * Get the key ID (last 8 hex digits of the key's finger print) embedded in the signature
   * @param encodedSignature  base64 encoded signature
   * @return key ID(short format)
   */
  public String getKeyID(String encodedSignature) throws IOException {
    return execScript(new String[] {script, GET_KEY_ID, encodedSignature});
  }


  /**
   * Get the signed data embedded in the encoded signature
   * @param encodedSignature base64 encoded signature
   * @return  signed data
   */
  public String getData(String encodedSignature) throws IOException {
    return execScript(new String[] {script, GET_DATA, encodedSignature});
  }

  private String execScript(String[] scriptAndArguments) throws IOException {
    final File tmp = File.createTempFile("out", null);
    final StringBuilder out = new StringBuilder();
    int exitCode = 1;
    InputStream is = null;
    try {
      tmp.deleteOnExit();
      ProcessBuilder processBuilder = new ProcessBuilder();
      processBuilder.command(scriptAndArguments).redirectErrorStream(true).redirectOutput(tmp);
      Process process = processBuilder.start();

      try {
        exitCode = process.waitFor();
      } catch (InterruptedException ie) {
        throw new IOException("Process did not finish gracefully.", ie);
      }

      is = new FileInputStream(tmp);
      int c;
      while ((c = is.read()) != -1) {
        out.append((char) c);
      }

    } finally {
      tmp.delete();
      if (is != null) {
        is.close();
      }
    }

    return out.toString();
  }


  private int getExitCodeOfExecScript(String[] scriptAndArguments) throws IOException {
    final File tmp = File.createTempFile("out", null);
    final StringBuilder out = new StringBuilder();
    int exitCode = 1;
    try {
      tmp.deleteOnExit();
      ProcessBuilder processBuilder = new ProcessBuilder();
      processBuilder.command(scriptAndArguments).redirectErrorStream(true).redirectOutput(tmp);
      Process process = processBuilder.start();

      try {
        exitCode = process.waitFor();
      } catch (InterruptedException ie) {
        throw new IOException("Process did not finish gracefully.", ie);
      }
    } finally {
      tmp.delete();
    }

    return exitCode;
  }

  public static void main(String[] args) throws IOException {
    GPGScriptWrapper scriptWrapper = new GPGScriptWrapper();
    String data = "Grafeas meta data";
    String base64EncodedSignature = scriptWrapper.sign(data);

    boolean validSig = scriptWrapper.verify(base64EncodedSignature);

    String embeddedKeyID = scriptWrapper.getKeyID(base64EncodedSignature);

    String embeddedData = scriptWrapper.getData(base64EncodedSignature);

    System.out.println("Java wrapper, base64 encoded signature of [" + data + "]: " + base64EncodedSignature);
    System.out.println("Java wrapper, is signature [" + base64EncodedSignature + "] valid? " + validSig);
    System.out.println("Java wrapper, embedded keyID: " + embeddedKeyID);
    System.out.println("Java wrapper, embedded data: " + embeddedData);
  }
}
