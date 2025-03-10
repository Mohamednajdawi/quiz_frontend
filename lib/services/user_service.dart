import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserData {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime? dateOfBirth;
  final DateTime createdAt;

  UserData({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.dateOfBirth,
    required this.createdAt,
  });

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserData(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null 
          ? (data['dateOfBirth'] as Timestamp).toDate() 
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user data
  Future<UserData?> getCurrentUserData() async {
    final User? user = _auth.currentUser;
    
    if (user == null) return null;
    
    try {
      final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
      
      if (docSnapshot.exists) {
        return UserData.fromFirestore(docSnapshot);
      }
      
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Get user data by ID
  Future<UserData?> getUserData(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      
      if (docSnapshot.exists) {
        return UserData.fromFirestore(docSnapshot);
      }
      
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Update user data
  Future<void> updateUserData({
    required String userId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      
      if (firstName != null) data['firstName'] = firstName;
      if (lastName != null) data['lastName'] = lastName;
      if (dateOfBirth != null) data['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }
} 