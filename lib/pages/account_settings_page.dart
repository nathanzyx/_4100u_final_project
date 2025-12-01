import 'package:flutter/material.dart';
import 'package:study_connect/services/client/client_services.dart';

class AccountSettingsPage extends StatefulWidget
{
  const AccountSettingsPage({super.key});
  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage>
{
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  bool _hidePassword = true;

  @override
  void dispose()
  {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }


  String? _validateDisplayName(String? v)
  {
    final s = (v ?? '').trim();

    if (s.isEmpty) return 'Display name can\'t be empty';
    if (s.length > 30) return 'Keep it under 30 characters';
    return null;
  }

  String? _validateUsername(String? v)
  {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Username can\'t be empty';
    final ok = RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(s);
    if (!ok) return '3–20 chars: letters/numbers/_ only';

    return null;
  }

  String? _validatePassword(String? v)
  {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Password can\'t be empty';
    if (s.length < 4) return 'Use 4+ characters';
    return null;
  }

  Future<void> _save() async
  {
    final svc = ClientService();
    final u = svc.currentUser!;
    if (!_formKey.currentState!.validate()) return;

    final newDisplayName = _displayNameCtrl.text.trim();
    final newUsername = _usernameCtrl.text.trim();
    final newPassword = _passwordCtrl.text.trim();

    final displayNameChanged = newDisplayName != u.displayName;
    final usernameChanged = newUsername != u.username;
    final passwordChanged = newPassword != u.password;

    if (!displayNameChanged && !usernameChanged && !passwordChanged)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() => _saving = true);
    try
    {
      await svc.updateAccount(
        displayName: displayNameChanged ? newDisplayName : null,
        username: usernameChanged ? newUsername : null,
        password: passwordChanged ? newPassword : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account updated')),
      );
      Navigator.pop(context);
    } 
    on UsernameTakenException
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That username is already taken')),
      );
    } 
    catch (e)
    {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
    finally
    {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final svc = ClientService();

    return FutureBuilder(
      future: svc.ensureUser(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final u = svc.currentUser!;
        if (!_initialized)
        {
          _displayNameCtrl.text = u.displayName;
          _usernameCtrl.text = u.username;
          _passwordCtrl.text = u.password;
          
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Account Settings')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [

                Form(
                  key: _formKey,
                  child: Column(
                    children: [

                      TextFormField(
                        controller: _displayNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateDisplayName,
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 15),

                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateUsername,
                        textInputAction: TextInputAction.next
                      ),
                      
                      const SizedBox(height: 15),

                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off)
                          ),
                        ),

                        validator: _validatePassword,
                        textInputAction: TextInputAction.done,
                      ),

                      const SizedBox(height: 15),
                      
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save changes'),
                        ),
                      ),
                    ],

                  ),
                ),
              ],
            ),
            
          ),
        );
      },
    );
  }
}
