/// Simple model class representing a user record from Odoo (`res.users` model).
///
/// Used throughout the app for:
/// • Displaying responsible persons / assigned users (e.g. MO responsible)
/// • Dropdown selections in forms
/// • Showing user names in lists/tables
///
/// Stores only the minimal fields needed: `id` and `name`.
class UserModel {
  final int id;
  final String name;

  UserModel({required this.id, required this.name});

  /// Factory constructor that creates a `UserModel` from an Odoo JSON response.
  ///
  /// Expected minimal JSON structure:
  /// ```json
  /// {
  ///   "id": 7,
  ///   "name": "John Doe"
  /// }
  /// ```
  ///
  /// - Uses `id` directly
  /// - Uses `name` directly
  /// - Falls back to 0 or empty string if fields are missing/null
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(id: json['id'] ?? 0, name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
