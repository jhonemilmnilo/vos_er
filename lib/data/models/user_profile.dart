class UserProfile {
  final int userId;
  final String userFname;
  final String? userMname;
  final String userLname;
  final String userEmail;
  final String? userContact;
  final String? userPosition;
  final String? userDepartment;
  final String? userDateOfHire;
  final String? userBrgy;
  final String? userCity;
  final String? userProvince;
  final String? userImage;
  final String? rfId;
  final String? userSss;
  final String? userPhilhealth;
  final String? userPagibig;
  final String? userTin;
  final String? role;
  final bool? isAdmin;
  final DateTime? updateAt;

  const UserProfile({
    required this.userId,
    required this.userFname,
    this.userMname,
    required this.userLname,
    required this.userEmail,
    this.userContact,
    this.userPosition,
    this.userDepartment,
    this.userDateOfHire,
    this.userBrgy,
    this.userCity,
    this.userProvince,
    this.userImage,
    this.rfId,
    this.userSss,
    this.userPhilhealth,
    this.userPagibig,
    this.userTin,
    this.role,
    this.isAdmin,
    this.updateAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as int? ?? 0,
      userFname: json['user_fname']?.toString() ?? '',
      userMname: json['user_mname']?.toString(),
      userLname: json['user_lname']?.toString() ?? '',
      userEmail: json['user_email']?.toString() ?? '',
      userContact: json['user_contact']?.toString(),
      userPosition: json['user_position']?.toString(),
      userDepartment: json['user_department']?.toString(),
      userDateOfHire: json['user_date_of_hire']?.toString(),
      userBrgy: json['user_brgy']?.toString(),
      userCity: json['user_city']?.toString(),
      userProvince: json['user_province']?.toString(),
      userImage: json['user_image']?.toString(),
      rfId: json['rf_id']?.toString(),
      userSss: json['user_sss']?.toString(),
      userPhilhealth: json['user_philhealth']?.toString(),
      // userPhilhealth: json['user_philhealth'] as String?,
      userPagibig: json['user_pagibig']?.toString(),
      userTin: json['user_tin']?.toString(),
      role: json['role']?.toString(),
      isAdmin: json['is_admin'] as bool?,
      updateAt: json['update_at'] != null ? DateTime.parse(json['update_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_fname': userFname,
      'user_mname': userMname,
      'user_lname': userLname,
      'user_email': userEmail,
      'user_contact': userContact,
      'user_position': userPosition,
      'user_department': userDepartment,
      'user_date_of_hire': userDateOfHire,
      'user_brgy': userBrgy,
      'user_city': userCity,
      'user_province': userProvince,
      'user_image': userImage,
      'rf_id': rfId,
      'user_sss': userSss,
      'user_philhealth': userPhilhealth,
      'user_pagibig': userPagibig,
      'user_tin': userTin,
      'role': role,
      'is_admin': isAdmin,
      'update_at': updateAt?.toIso8601String(),
    };
  }
}
