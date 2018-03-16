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
  private final String SIGN = "sign";
  private final String VERIFY = "verify";
  private final String GET_KEY_ID = "getkeyid";
  private final String GET_DATA = "getdata";

  /**
   * Use the GPG_SCRIPT environment variable defined in the Wercker pipeline
   */
  public GPGScriptWrapper() {
    script = System.getenv("GPG_SCRIPT");
  }

  /**
   *
   * @param script full path of the GPG script.  Should be under GPG_SCRIPT Wercker env variable
   */
  public GPGScriptWrapper(String script) {
    this.script = script;
  }


  /**
   *
   * @param keyUID key uid, e.g. image.signer@oracle.com
   * @param data data to be signed
   * @return  Base64 encoding of the signature
   */
  public String sign(String keyUID, String data) throws IOException {
    return execScript(new String[] {script, SIGN, keyUID, data});
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

       try (InputStream is = new FileInputStream(tmp)) {
         int c;
         while ((c = is.read()) != -1) {
           out.append((char) c);
         }
       }

     } finally {
       tmp.delete();
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
    String data = "one";
    String base64EncodedSignature = scriptWrapper.sign("abc@def.com", data);

    boolean validSig = scriptWrapper.verify(base64EncodedSignature);

    String embeddedKeyID = scriptWrapper.getKeyID(base64EncodedSignature);

    String embeddedData = scriptWrapper.getData(base64EncodedSignature);

    System.out.println("Java wrapper, base64 encoded signature of [" + data + "]: " + base64EncodedSignature);
    System.out.println("Java wrapper, is signature [" + base64EncodedSignature + "] valid? " + validSig);
    System.out.println("Java wrapper, embedded keyID: " + embeddedKeyID);
    System.out.println("Java wrapper, embedded data: " + embeddedData);
  }
}
