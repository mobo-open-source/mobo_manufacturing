/// Represents a user or contact profile with personal and professional details.
///
/// This model is typically used to store and manage partner/contact information
/// fetched from an Odoo backend (or similar ERP/CRM system). It includes fields
/// like name, contact details, job position, company, full address breakdown,
/// and profile image (usually base64 or URL).
///
/// The [fromJson] factory handles Odoo's common response format where relational
/// fields (company_id, state_id, country_id) are returned as [id, name] lists.
class Profile {
  final int id;
  final String name;
  final String phone;
  final String mail;
  final String address;
  final String mobile;
  final String website;
  final String jobTitle;
  final String image;
  final String company;
  final String street;
  final String street2;
  final String state;
  final int stateId;
  final String country;
  final int countryId;

  Profile({
    required this.id,
    required this.name,
    required this.phone,
    required this.mail,
    required this.address,
    required this.mobile,
    required this.website,
    required this.jobTitle,
    required this.image,
    required this.company,
    required this.street,
    required this.street2,
    required this.state,
    required this.stateId,
    required this.country,
    required this.countryId,
  });

  /// Creates a Profile instance from JSON data, usually from an Odoo RPC response.
  ///
  /// Handles Odoo's relational field format ([id, display_name]) and safely
  /// converts null/false values to empty strings or zero.
  factory Profile.fromJson(Map<String, dynamic> json) {
    String extractName(dynamic field) {
      if (field is List && field.length >= 2) {
        return field[1]?.toString() ?? '';
      }
      return '';
    }

    int extractId(dynamic field) {
      if (field is List && field.isNotEmpty) {
        return field[0] ?? 0;
      }
      return 0;
    }

    String extractStringField(dynamic field) {
      if (field == null || field == false) {
        return '';
      }
      return field.toString();
    }

    return Profile(
      id: json['id'] ?? 0,
      name: extractStringField(json['name']),
      phone: extractStringField(json['phone']),
      mail: extractStringField(json['email']),
      address: extractStringField(json['contact_address']),
      mobile: extractStringField(json['mobile']),
      website: extractStringField(json['website']),
      jobTitle: extractStringField(json['function']),
      image: extractStringField(json['image_1920']),
      company: extractName(json['company_id']),
      street: extractStringField(json['street']),
      street2: extractStringField(json['street2']),
      state: extractName(json['state_id']),
      stateId: extractId(json['state_id']),
      country: extractName(json['country_id']),
      countryId: extractId(json['country_id']),
    );
  }

  /// Converts this profile back to a JSON-compatible map.
  ///
  /// Useful when sending updated profile data back to the server or
  /// storing it locally.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': mail,
      'address': address,
      'mobile': mobile,
      'website': website,
      'jobTitle': jobTitle,
      'image': image,
      'company': company,
      'street': street,
      'street2': street2,
      'state': state,
      'stateId': stateId,
      'country': country,
      'countryId': countryId,
    };
  }

  /// Returns a default/empty profile with safe fallback values.
  ///
  /// Commonly used as initial state in UI controllers or when no real data
  /// is available yet (e.g. before login or during loading).
  factory Profile.defaultProfile() {
    return Profile(
      id: 0,
      name: 'Unknown',
      phone: '',
      mail: '',
      address: '',
      mobile: '',
      website: '',
      jobTitle: '',
      image: '',
      company: '',
      street: '',
      street2: '',
      state: '',
      stateId: 0,
      country: '',
      countryId: 0,
    );
  }
}
