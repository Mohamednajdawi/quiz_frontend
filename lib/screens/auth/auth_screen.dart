import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLogin = true;
  bool _isLoading = false;
  
  // Add individual field validation flags
  bool _firstNameValidated = true;
  bool _lastNameValidated = true;
  bool _emailValidated = true;
  bool _passwordValidated = true;
  bool _confirmPasswordValidated = true;

  // Validate individual fields
  void _validateFields() {
    setState(() {
      if (!_isLogin) {
        _firstNameValidated = _firstNameController.text.isNotEmpty;
        _lastNameValidated = _lastNameController.text.isNotEmpty;
        _confirmPasswordValidated = _confirmPasswordController.text.isNotEmpty && 
                                    _confirmPasswordController.text == _passwordController.text;
      }
      _emailValidated = _emailController.text.isNotEmpty && _emailController.text.contains('@');
      _passwordValidated = _passwordController.text.isNotEmpty && _passwordController.text.length >= 6;
    });
  }

  Future<void> _submitForm() async {
    // First validate all fields
    final isValid = _formKey.currentState!.validate();
    
    // Manually validate fields in case form validation misses anything
    _validateFields();
    
    // Check if any individual field is invalid
    bool allFieldsValid = _emailValidated && _passwordValidated;
    if (!_isLogin) {
      allFieldsValid = allFieldsValid && _firstNameValidated && _lastNameValidated && _confirmPasswordValidated;
    }
    
    // If any validation fails, return early
    if (!isValid || !allFieldsValid) return;
    
    // Check date of birth for registration
    if (!_isLogin && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Create the user in Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        // Update the user's display name with first and last name
        await userCredential.user?.updateDisplayName(
          "${_firstNameController.text} ${_lastNameController.text}"
        );
        
        // Store additional user data in Firestore
        if (userCredential.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'email': _emailController.text.trim(),
            'dateOfBirth': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign in with Google')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isLogin) ...[
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    border: const OutlineInputBorder(),
                    errorText: !_firstNameValidated ? 'Please enter your first name' : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _firstNameValidated = value.isNotEmpty;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    border: const OutlineInputBorder(),
                    errorText: !_lastNameValidated ? 'Please enter your last name' : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _lastNameValidated = value.isNotEmpty;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  errorText: !_emailValidated ? 'Please enter a valid email' : null,
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  setState(() {
                    _emailValidated = value.isNotEmpty && value.contains('@');
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  errorText: !_passwordValidated ? 'Password must be at least 6 characters' : null,
                ),
                obscureText: true,
                onChanged: (value) {
                  setState(() {
                    _passwordValidated = value.isNotEmpty && value.length >= 6;
                    
                    // Also validate confirm password if in register mode
                    if (!_isLogin && _confirmPasswordController.text.isNotEmpty) {
                      _confirmPasswordValidated = _confirmPasswordController.text == value;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              
              if (!_isLogin) ...[
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    errorText: !_confirmPasswordValidated ? 'Passwords do not match' : null,
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    setState(() {
                      _confirmPasswordValidated = value.isNotEmpty && value == _passwordController.text;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null 
                              ? 'Select Date' 
                              : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                if (!_isLogin && _formKey.currentState?.validate() == true && _selectedDate == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, left: 12.0),
                    child: Text(
                      'Please select your date of birth',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading 
                    ? null 
                    : () {
                        // Validate all fields first
                        _validateFields();
                        if (_formKey.currentState?.validate() ?? false) {
                          _submitForm();
                        }
                      },
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(_isLogin ? 'Login' : 'Register'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : _signInWithGoogle,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login),
                    SizedBox(width: 8),
                    Text('Sign in with Google'),
                  ],
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isLogin = !_isLogin;
                          // Reset validation flags when switching modes
                          _firstNameValidated = true;
                          _lastNameValidated = true;
                          _emailValidated = true;
                          _passwordValidated = true;
                          _confirmPasswordValidated = true;
                        });
                      },
                child: Text(_isLogin
                    ? 'Don\'t have an account? Register'
                    : 'Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 