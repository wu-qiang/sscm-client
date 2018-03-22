package com.oracle.sscm.client.script;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Wrapper class to invoke the GPG_SCRIPT for signing and verifying signatures
 * This GPG_SCRIPT calls the OS gpg command
 */
public class GPGScriptWrapper {
  private static final String SIGN = "--sign";
  private static final String VERIFY = "--verify";
  private static final String GET_KEY_ID = "--get-signature-keyid";
  private static final String GET_DATA = "--get-signature-data";
  private static final String INIT_KEYRING = "--init-keyring";
  private static final String GET_AUTHORITY_NAMES = "--get-authority-names";
  private static final String GET_AUTHORITY_KEY_ID = "--get-authority-keyid";

  private static final String GPG_SCRIPT_ENV_VAR = "GPG_SCRIPT";
  private static final String GPG_AUTHORITY_NAME_ENV_VAR = "GPG_AUTHORITY_NAME";

  private static String script = System.getenv(GPG_SCRIPT_ENV_VAR);
  private String gpgAuthorityName;

  static {
    initKeyRing();
  }

  /**
   * Use the GPG_SCRIPT, environment variable defined in the Wercker pipeline
   * Use the first element from the getAuthorityNames() list as the authority name
   */
  public GPGScriptWrapper() {
    try {
      gpgAuthorityName = getAuthorityNames()[0];
    } catch (IOException ioe) {
      System.err.println("Failed to get the Authority Names: " + ioe);
      throw new IllegalStateException("Authority name is not defined.");
    }
  }


  /**
   * Use the GPG_SCRIPT, environment variable defined in the Wercker pipeline
   * @param gpgAuthorityName full name of an attestation authority
   */
  public GPGScriptWrapper(String gpgAuthorityName) {
    this.gpgAuthorityName = gpgAuthorityName;
  }


  /**
   *
   * @return true if the key ring is initialized successfully, false otherwise.
   */
  private static boolean initKeyRing() {
    if (script == null) {
      throw new IllegalStateException("Environment variable GPG_SCRIPT is not set.");
    }

    if (!new File(script).exists()) {
      throw new IllegalStateException("Script " + script + " is not found.");
    }

    int exitCode = 1;
    try {
      exitCode = getExitCodeOfExecScript(new String[]{script, INIT_KEYRING});
    } catch(IOException ioe) {
      System.err.println("Failed to initialize the key ring: " + ioe);
      throw new IllegalStateException("Key ring is not initialized", ioe);
    }

    return exitCode == 0;
  }


  /**
   *
   * Sign the data with the authority name from getAuthorityNames().get(0)
   *
   * @param data data to be signed
   * @return  Base64 encoding of the signature
   */
  public String sign(String data) throws IOException {
    return execScript(new String[] {script, SIGN, gpgAuthorityName, data});
  }


  /**
   *
   * @param authorityName full name of attestation authority
   * @param data data to be signed
   * @return  Base64 encoding of the signature
   */
  public static String sign(String authorityName, String data) throws IOException {
    return execScript(new String[] {script, SIGN, authorityName, data});
  }


  /**
   * Verify the base64 encoded signature
   * @param encodedSignature  base64 encoded signature
   * @return  true if the signature is valid, false otherwise
   */
  public static boolean verify(String encodedSignature) throws IOException {
    return getExitCodeOfExecScript(new String[] {script, VERIFY, encodedSignature}) == 0;
  }


  /**
   * Get the key ID (last 8 hex digits of the key's finger print) embedded in the signature
   * @param encodedSignature  base64 encoded signature
   * @return key ID(short format)
   */
  public static String getKeyID(String encodedSignature) throws IOException {
    return execScript(new String[] {script, GET_KEY_ID, encodedSignature});
  }


  /**
   * Get the signed data embedded in the encoded signature
   * @param encodedSignature base64 encoded signature
   * @return  signed data
   */
  public static String getData(String encodedSignature) throws IOException {
    return execScript(new String[] {script, GET_DATA, encodedSignature});
  }


  /**
   * Authority names returned by the script are separated by the new line character.
   * @return List of authority names from the key ring
   */
  public static String[] getAuthorityNames() throws IOException {
    return execScript(new String[] {script, GET_AUTHORITY_NAMES}).split("\n");
  }


  public static String getAuthorityKeyID(String authorityName) throws IOException {
    return execScript(new String[] {script, GET_AUTHORITY_KEY_ID, authorityName});
  }


  private static String execScript(String[] scriptAndArguments) throws IOException {
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


  private static int getExitCodeOfExecScript(String[] scriptAndArguments) throws IOException {
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

    boolean validSig = GPGScriptWrapper.verify(base64EncodedSignature);

    String embeddedKeyID = GPGScriptWrapper.getKeyID(base64EncodedSignature);

    String embeddedData = GPGScriptWrapper.getData(base64EncodedSignature);

    System.out.println("Java wrapper, base64 encoded signature of [" + data + "]: " + base64EncodedSignature);
    System.out.println("Java wrapper, is signature [" + base64EncodedSignature + "] valid? " + validSig);
    System.out.println("Java wrapper, embedded keyID: " + embeddedKeyID);
    System.out.println("Java wrapper, embedded data: " + embeddedData);
    String authName = GPGScriptWrapper.getAuthorityNames()[0];
    System.out.println("Java wrapper, getAuthorityNames(): [" + authName + "]");
    System.out.println("Java wrapper, System.getenv('GPG_AUTHORITY_NAME_ENV_VAR'): [" + System.getenv(GPG_AUTHORITY_NAME_ENV_VAR) + "]");
    System.out.println("Java wrapper, getAuthorityKeyID(getAuthorityNames().get(0)): " + GPGScriptWrapper.getAuthorityKeyID(authName));
    System.out.println("Java wrapper, getAuthorityKeyID(System.getenv('GPG_AUTHORITY_NAME')): " + GPGScriptWrapper.getAuthorityKeyID(System.getenv(GPG_AUTHORITY_NAME_ENV_VAR)));
    System.out.println("Java wrapper, sign(authority_name, data): " + GPGScriptWrapper.sign(authName, data));

    GPGScriptWrapper scriptWrapper1 = new GPGScriptWrapper(authName);
    System.out.println("Java wrapper, signed data with another constructor: " + scriptWrapper1.sign("some data"));
  }
}
