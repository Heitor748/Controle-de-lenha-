import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;

/// Singleton service that uploads files to the signed-in user's Google Drive.
class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  // ─── Google Sign-In ───────────────────────────────────────────────────────────

  static const List<String> _scopes = [
    drive.DriveApi.driveFileScope, // create / open files created by this app
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  // ─── Public API ───────────────────────────────────────────────────────────────

  /// Uploads the file at [filePath] to Google Drive and returns its
  /// `webViewLink`, or `null` if the upload fails or the user cancels sign-in.
  ///
  /// [fileName] is the display name shown in Drive.
  /// [mimeType] must be the correct MIME type (e.g. `'application/pdf'`,
  /// `'image/jpeg'`).
  Future<String?> uploadFile(
    String filePath,
    String fileName,
    String mimeType,
  ) async {
    try {
      // ── authenticate ──────────────────────────────────────────────────────
      final GoogleSignInAccount? account = await _signIn();
      if (account == null) return null; // user cancelled

      final http.Client httpClient = await _buildHttpClient(account);

      try {
        // ── build Drive API client ────────────────────────────────────────
        final drive.DriveApi driveApi = drive.DriveApi(httpClient);

        // ── prepare file metadata ─────────────────────────────────────────
        final drive.File fileMetadata = drive.File()
          ..name = fileName
          ..mimeType = mimeType;

        // ── prepare media stream ──────────────────────────────────────────
        final File localFile = File(filePath);
        if (!localFile.existsSync()) {
          throw FileSystemException('File not found', filePath);
        }

        final drive.Media media = drive.Media(
          localFile.openRead(),
          localFile.lengthSync(),
          contentType: mimeType,
        );

        // ── upload ────────────────────────────────────────────────────────
        final drive.File uploaded = await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
          $fields: 'id,webViewLink',
        );

        // Make the file readable by anyone with the link (optional –
        // comment out if you want the file to stay private).
        if (uploaded.id != null) {
          await driveApi.permissions.create(
            drive.Permission()
              ..role = 'reader'
              ..type = 'anyone',
            uploaded.id!,
          );
        }

        return uploaded.webViewLink;
      } finally {
        httpClient.close();
      }
    } on GoogleSignIn catch (e) {
      // Auth-specific error — surface as null to let callers handle gracefully.
      // ignore: avoid_print
      print('DriveService: Google Sign-In error – $e');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('DriveService.uploadFile: error – $e');
      rethrow;
    }
  }

  /// Signs the user out of Google (clears cached credentials).
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  Future<GoogleSignInAccount?> _signIn() async {
    // Return existing account if already signed in.
    if (_googleSignIn.currentUser != null) return _googleSignIn.currentUser;

    // Try silent sign-in first (no UI if token is still valid).
    GoogleSignInAccount? account = await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    return account;
  }

  Future<http.Client> _buildHttpClient(GoogleSignInAccount account) async {
    final GoogleSignInAuthentication googleAuth =
        await account.authentication;

    final auth.AccessCredentials credentials = auth.AccessCredentials(
      auth.AccessToken(
        'Bearer',
        googleAuth.accessToken!,
        // Drive tokens are typically valid for 1 hour from now.
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      googleAuth.idToken,
      _scopes,
    );

    return auth.authenticatedClient(http.Client(), credentials);
  }
}
