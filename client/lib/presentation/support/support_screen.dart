import "package:flutter/material.dart";

import "../../core/api/general_api.dart";

class SupportScreenArgs {
  SupportScreenArgs({required this.accessToken});

  final String accessToken;
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.generalApi,
    required this.accessToken,
  });

  final GeneralApi generalApi;
  final String accessToken;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  String _feedback = "";
  Map<String, String> _contactInfo = const {};
  List<Map<String, dynamic>> _contactTypes = const [];
  int? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _feedback = "";
    });
    try {
      final results = await Future.wait([
        widget.generalApi.contactInfo(),
        widget.generalApi.contactTypes(),
      ]);
      setState(() {
        _contactInfo = results[0] as Map<String, String>;
        _contactTypes = results[1] as List<Map<String, dynamic>>;
        if (_contactTypes.isNotEmpty) {
          _selectedTypeId = (_contactTypes.first["id"] as num?)?.toInt();
        }
      });
    } catch (e) {
      setState(() => _feedback = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedTypeId == null) return;
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _feedback = "Please fill in subject and message.");
      return;
    }
    setState(() {
      _sending = true;
      _feedback = "";
    });
    try {
      await widget.generalApi.submitContactReport(
        accessToken: widget.accessToken,
        contactTypeId: _selectedTypeId!,
        subject: subject,
        message: message,
      );
      _subjectController.clear();
      _messageController.clear();
      setState(() => _feedback = "Your message has been submitted.");
    } catch (e) {
      setState(() => _feedback = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17181C),
        foregroundColor: const Color(0xFFF2D05C),
        title: Text(
          "SUPPORT",
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFF2D05C),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_contactInfo.isNotEmpty) ...[
                  Text(
                    "Contact Us",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFF4D58A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._contactInfo.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "${e.key}: ${e.value}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  "Send a Report",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFF4D58A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_contactTypes.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: _selectedTypeId,
                    dropdownColor: const Color(0xFF17181C),
                    style: const TextStyle(color: Color(0xFFF0F0F0)),
                    decoration: InputDecoration(
                      labelText: "Category",
                      labelStyle: const TextStyle(color: Color(0xFFF4D58A)),
                      filled: true,
                      fillColor: const Color(0xFF17181C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _contactTypes
                        .map(
                          (t) => DropdownMenuItem<int>(
                            value: (t["id"] as num?)?.toInt(),
                            child:
                                Text(t["name"]?.toString() ?? ""),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTypeId = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subjectController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Subject",
                    labelStyle: const TextStyle(color: Color(0xFFF4D58A)),
                    filled: true,
                    fillColor: const Color(0xFF17181C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: "Message",
                    labelStyle: const TextStyle(color: Color(0xFFF4D58A)),
                    filled: true,
                    fillColor: const Color(0xFF17181C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                if (_feedback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _feedback,
                      style: TextStyle(
                        color: _feedback.startsWith("Your")
                            ? const Color(0xFF4CAF50)
                            : theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B6E4F),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("SUBMIT"),
                ),
              ],
            ),
    );
  }
}
