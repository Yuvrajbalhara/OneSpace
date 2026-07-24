import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://zpvwsqhjnjftizlcztak.supabase.co';
const supabasePublishableKey = 'sb_publishable_RHzGxOMz_b1tmh3Wsne-Xw_tewhUrxT';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const OneSpaceApp());
}

class OneSpaceApp extends StatefulWidget {
  const OneSpaceApp({super.key});

  @override
  State<OneSpaceApp> createState() => _OneSpaceAppState();
}

class _OneSpaceAppState extends State<OneSpaceApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late final StreamSubscription<AuthState> _authSubscription;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() => _session = data.session);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7C5CFC);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OneSpace',
      themeMode: _themeMode,
      theme: _theme(seed, Brightness.light),
      darkTheme: _theme(seed, Brightness.dark),
      home: _session == null
          ? const AuthPage()
          : AppShell(
              key: ValueKey(_session!.user.id),
              themeMode: _themeMode,
              onThemeChanged: (value) => setState(() => _themeMode = value),
            ),
    );
  }

  ThemeData _theme(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: brightness == Brightness.dark
          ? const Color(0xFF111116)
          : const Color(0xFFF7F7FB),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.dark
            ? const Color(0xFF1A1A22)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6 || (_registering && _name.text.trim().isEmpty)) {
      setState(() => _error = 'Enter a valid email, name, and a password of at least 6 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (_registering) {
        await auth.signUp(email: email, password: password, data: {'full_name': _name.text.trim()});
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not connect. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Align(alignment: Alignment.centerLeft, child: _Logo(size: 52)),
                const SizedBox(height: 22),
                Text(_registering ? 'Create your OneSpace' : 'Welcome back', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(_registering ? 'Your library will stay synchronized across your devices.' : 'Sign in to access your synchronized workspace.'),
                const SizedBox(height: 24),
                if (_registering) ...[
                  TextField(controller: _name, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded))),
                  const SizedBox(height: 12),
                ],
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                TextField(controller: _password, obscureText: _hidePassword, onSubmitted: (_) => _submit(), autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: _loading ? null : _submit, icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_registering ? Icons.person_add_alt_1_rounded : Icons.login_rounded), label: Text(_registering ? 'Create account' : 'Sign in')),
                const SizedBox(height: 8),
                TextButton(onPressed: _loading ? null : () => setState(() { _registering = !_registering; _error = null; }), child: Text(_registering ? 'Already have an account? Sign in' : 'New to OneSpace? Create an account')),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

class LibraryItem {
  const LibraryItem({
    required this.title,
    required this.category,
    required this.description,
    required this.date,
    required this.icon,
    required this.color,
    required this.tags,
    this.favorite = false,
    this.imagePath,
    this.id,
    this.storagePath,
    this.imageUrl,
  });

  final String title;
  final String category;
  final String description;
  final String date;
  final IconData icon;
  final Color color;
  final List<String> tags;
  final bool favorite;
  final String? imagePath;
  final String? id;
  final String? storagePath;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'description': description,
        'date': date,
        'tags': tags,
        'favorite': favorite,
        'imagePath': imagePath,
        'id': id,
        'storagePath': storagePath,
      };

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String? ?? 'Documents';
    final style = _categoryStyle(category);
    return LibraryItem(
      title: json['title'] as String? ?? 'Untitled item',
      category: category,
      description: json['description'] as String? ?? '',
      date: json['date'] as String? ?? 'Saved recently',
      icon: style.$1,
      color: style.$2,
      tags: List<String>.from(json['tags'] as List? ?? const []),
      favorite: json['favorite'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
      id: json['id'] as String?,
      storagePath: json['storagePath'] as String?,
    );
  }

  LibraryItem copyWith({bool? favorite}) => LibraryItem(
        title: title,
        category: category,
        description: description,
        date: date,
        icon: icon,
        color: color,
        tags: tags,
        favorite: favorite ?? this.favorite,
        imagePath: imagePath,
        id: id,
        storagePath: storagePath,
        imageUrl: imageUrl,
      );
}

(IconData, Color) _categoryStyle(String category) => switch (category) {
      'Screenshots' => (Icons.image_rounded, const Color(0xFF45B6FE)),
      'Receipts' => (Icons.receipt_long_rounded, const Color(0xFFFFA657)),
      'Notes' => (Icons.sticky_note_2_rounded, const Color(0xFF44D7B6)),
      'Links' => (Icons.link_rounded, const Color(0xFF6F8CFF)),
      _ => (Icons.description_rounded, const Color(0xFF7C5CFC)),
    };

const sampleItems = <LibraryItem>[
  LibraryItem(
    title: 'Residence permit checklist',
    category: 'Documents',
    description: 'Passport, biometric photo, enrollment certificate and proof of residence.',
    date: 'Today, 09:42',
    icon: Icons.description_rounded,
    color: Color(0xFF7C5CFC),
    tags: ['university', 'important'],
    favorite: true,
  ),
  LibraryItem(
    title: 'Flutter responsive layout',
    category: 'Screenshots',
    description: 'Use LayoutBuilder and NavigationRail for screens wider than 760 pixels.',
    date: 'Yesterday',
    icon: Icons.image_rounded,
    color: Color(0xFF45B6FE),
    tags: ['flutter', 'development'],
  ),
  LibraryItem(
    title: 'Laptop purchase receipt',
    category: 'Receipts',
    description: 'Lenovo LOQ purchase invoice and payment information.',
    date: '17 Jul 2026',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFFFA657),
    tags: ['electronics', 'invoice'],
  ),
  LibraryItem(
    title: 'Database assignment notes',
    category: 'Notes',
    description: 'Normalization, relationships, primary keys and foreign keys.',
    date: '14 Jul 2026',
    icon: Icons.sticky_note_2_rounded,
    color: Color(0xFF44D7B6),
    tags: ['university', 'database'],
    favorite: true,
  ),
  LibraryItem(
    title: 'Cloud architecture diagram',
    category: 'Screenshots',
    description: 'Cloud Run, load balancer, CDN, SQL, storage, IAM and monitoring.',
    date: '12 Jul 2026',
    icon: Icons.account_tree_rounded,
    color: Color(0xFFFF6B8A),
    tags: ['cloud', 'architecture'],
  ),
  LibraryItem(
    title: 'Useful Flutter resources',
    category: 'Links',
    description: 'Material 3 documentation and responsive design guidelines.',
    date: '10 Jul 2026',
    icon: Icons.link_rounded,
    color: Color(0xFF6F8CFF),
    tags: ['flutter', 'reference'],
  ),
];

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _searchController = TextEditingController();
  final _preferences = SharedPreferencesAsync();
  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _itemsSubscription;
  Timer? _syncTimer;
  List<LibraryItem> _items = [];
  bool _loadingItems = true;
  bool _refreshingItems = false;

  static const destinations = [
    (Icons.space_dashboard_rounded, 'Home'),
    (Icons.folder_copy_rounded, 'Library'),
    (Icons.search_rounded, 'Search'),
    (Icons.auto_awesome_rounded, 'Tools'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _initialiseCloudLibrary();
  }

  Future<void> _initialiseCloudLibrary() async {
    try {
      final user = _supabase.auth.currentUser!;
      final existing = await _supabase.from('library_items').select('id').eq('user_id', user.id).limit(1);
      final migrationKey = 'cloud_migrated_${user.id}';
      final migrated = await _preferences.getBool(migrationKey) ?? false;
      if ((existing as List).isEmpty && !migrated) {
        final saved = await _preferences.getString('onespace_library');
        if (saved != null) {
          final decoded = jsonDecode(saved) as List<dynamic>;
          for (final value in decoded) {
            await _createCloudItem(LibraryItem.fromJson(value as Map<String, dynamic>), notify: false);
          }
        }
        await _preferences.setBool(migrationKey, true);
      }
      await _refreshCloudItems();
      _itemsSubscription = _supabase
          .from('library_items')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .listen(
            (rows) => _hydrateRows(rows),
            onError: (_) {
              // Direct refresh and polling below keep sync working when
              // Realtime replication is not enabled for this table.
            },
          );
      _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshCloudItems());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud connection failed: $error')));
    }
    if (mounted) setState(() => _loadingItems = false);
  }

  Future<void> _refreshCloudItems() async {
    if (_refreshingItems || _supabase.auth.currentUser == null) return;
    _refreshingItems = true;
    try {
      final rows = await _supabase
          .from('library_items')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);
      await _hydrateRows(List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      if (mounted && _items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load your cloud library: $error')));
      }
    } finally {
      _refreshingItems = false;
    }
  }

  Future<void> _hydrateRows(List<Map<String, dynamic>> rows) async {
    final hydrated = <LibraryItem>[];
    for (final row in rows) {
      String? imageUrl;
      final storagePath = row['image_path'] as String?;
      if (storagePath != null) {
        try {
          imageUrl = await _supabase.storage.from('library-images').createSignedUrl(storagePath, 3600);
        } catch (_) {}
      }
      final category = row['category'] as String? ?? 'Documents';
      final style = _categoryStyle(category);
      hydrated.add(LibraryItem(
        id: row['id'] as String,
        title: row['title'] as String? ?? 'Untitled',
        category: category,
        description: row['description'] as String? ?? '',
        date: _friendlyDate(row['created_at'] as String?),
        icon: style.$1,
        color: style.$2,
        tags: List<String>.from(row['tags'] as List? ?? const []),
        favorite: row['favorite'] as bool? ?? false,
        storagePath: storagePath,
        imageUrl: imageUrl,
      ));
    }
    if (mounted) setState(() { _items = hydrated; _loadingItems = false; });
  }

  String _friendlyDate(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return 'Recently';
    final now = DateTime.now();
    if (now.difference(date).inHours < 24) return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _createCloudItem(LibraryItem item, {bool notify = true}) async {
    final user = _supabase.auth.currentUser!;
    String? storagePath;
    if (item.imagePath != null && await File(item.imagePath!).exists()) {
      final extension = item.imagePath!.contains('.') ? item.imagePath!.substring(item.imagePath!.lastIndexOf('.')) : '.jpg';
      storagePath = '${user.id}/${DateTime.now().microsecondsSinceEpoch}$extension';
      await _supabase.storage.from('library-images').upload(storagePath, File(item.imagePath!));
    }
    await _supabase.from('library_items').insert({
      'user_id': user.id,
      'title': item.title,
      'category': item.category,
      'description': item.description,
      'tags': item.tags,
      'favorite': item.favorite,
      'image_path': storagePath,
    });
    await _refreshCloudItems();
    if (notify && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved and synchronized.')));
  }

  Future<void> _updateCloudItem(LibraryItem item) async {
    if (item.id == null) return;
    await _supabase.from('library_items').update({
      'title': item.title,
      'category': item.category,
      'description': item.description,
      'tags': item.tags,
      'favorite': item.favorite,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', item.id!);
    await _refreshCloudItems();
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _syncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showCommandPalette,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 760;
            final pages = [
              DashboardPage(items: _items, onNavigate: _goTo, onAdd: _showAddSheet, onEdit: _editItem, onDelete: _deleteItem, onToggleFavorite: _toggleFavorite),
              LibraryPage(items: _items, onEdit: _editItem, onDelete: _deleteItem, onToggleFavorite: _toggleFavorite),
              SearchPage(controller: _searchController, items: _items, onEdit: _editItem, onDelete: _deleteItem, onToggleFavorite: _toggleFavorite),
              const ToolsPage(),
              SettingsPage(
                themeMode: widget.themeMode,
                onThemeChanged: widget.onThemeChanged,
              ),
            ];
            return Scaffold(
              body: Row(
                children: [
                  if (desktop) _desktopNavigation(),
                  Expanded(
                    child: SafeArea(
                      left: false,
                      child: Column(
                        children: [
                          _TopBar(
                            pageName: destinations[_index].$2,
                            desktop: desktop,
                            onSearch: () => _goTo(2),
                            onCommand: _showCommandPalette,
                          ),
                          Expanded(
                            child: _loadingItems
                                ? const Center(child: CircularProgressIndicator())
                                : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey(_index),
                                child: pages[_index],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: desktop ? null : _mobileNavigation(),
              floatingActionButton: !desktop && _index == 1
                  ? FloatingActionButton.extended(
                      onPressed: _showAddSheet,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _desktopNavigation() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 230,
      color: colors.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _Logo(size: 38),
                SizedBox(width: 12),
                Text('OneSpace', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  selected: _index == i,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(destinations[i].$1),
                  title: Text(destinations[i].$2),
                  onTap: () => _goTo(i),
                ),
              ),
            ),
          const Spacer(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_done_rounded, color: colors.primary),
                  const SizedBox(height: 10),
                  const Text('Cloud workspace', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${_items.length} items available', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  NavigationBar _mobileNavigation() => NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          for (final item in destinations)
            NavigationDestination(icon: Icon(item.$1), label: item.$2),
        ],
      );

  void _goTo(int index) => setState(() => _index = index);

  void _showCommandPalette() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CommandPalette(
        onSelected: (index) {
          Navigator.pop(dialogContext);
          if (index >= 0) _goTo(index);
          if (index == -2) _showAddSheet();
        },
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add to OneSpace', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (Platform.isAndroid)
                  _ActionChip(icon: Icons.document_scanner_rounded, label: 'Scan document', onTap: () { Navigator.pop(sheetContext); _captureItem(ImageSource.camera); }),
                _ActionChip(icon: Icons.upload_file_rounded, label: 'Import image', onTap: () { Navigator.pop(sheetContext); _captureItem(ImageSource.gallery); }),
                _ActionChip(icon: Icons.note_add_rounded, label: 'Create note', onTap: () { Navigator.pop(sheetContext); _openItemForm(); }),
                _ActionChip(icon: Icons.add_link_rounded, label: 'Save link', onTap: () => _notReady(sheetContext, 'Link saving')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _notReady(BuildContext sheetContext, String feature) {
    Navigator.pop(sheetContext);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature is the next implementation step.')));
  }

  Future<void> _captureItem(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (picked == null) return;

      final support = await getApplicationSupportDirectory();
      final images = Directory('${support.path}${Platform.pathSeparator}library_images');
      await images.create(recursive: true);
      final extension = picked.path.contains('.') ? picked.path.substring(picked.path.lastIndexOf('.')) : '.jpg';
      final stored = await File(picked.path).copy('${images.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}$extension');

      var extractedText = '';
      if (Platform.isAndroid) {
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final result = await recognizer.processImage(InputImage.fromFilePath(stored.path));
          extractedText = result.text.trim();
        } finally {
          await recognizer.close();
        }
      }
      if (!mounted) return;
      await _openItemForm(imagePath: stored.path, extractedText: extractedText);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not import image: $error')));
    }
  }

  Future<void> _editItem(LibraryItem item) => _openItemForm(existing: item);

  Future<void> _toggleFavorite(LibraryItem item) async {
    final index = _items.indexOf(item);
    if (index < 0) return;
    setState(() => _items = [..._items]..[index] = item.copyWith(favorite: !item.favorite));
    try {
      await _supabase.from('library_items').update({'favorite': !item.favorite}).eq('id', item.id!);
      await _refreshCloudItems();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not synchronize favorite: $error')));
    }
  }

  Future<void> _deleteItem(LibraryItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete this item?'),
        content: Text('“${item.title}” will be removed from every synchronized device. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _items = _items.where((value) => !identical(value, item)).toList());
    try {
      await _supabase.from('library_items').delete().eq('id', item.id!);
      if (item.storagePath != null) await _supabase.storage.from('library-images').remove([item.storagePath!]);
      await _refreshCloudItems();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete item: $error')));
      return;
    }
    final path = item.imagePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted.')));
  }

  Future<void> _openItemForm({String? imagePath, String extractedText = '', LibraryItem? existing}) async {
    final firstLine = extractedText.split('\n').where((line) => line.trim().isNotEmpty).firstOrNull;
    final suggested = firstLine?.trim() ?? '';
    final title = TextEditingController(text: existing?.title ?? (suggested.length > 55 ? suggested.substring(0, 55) : suggested));
    final description = TextEditingController(text: existing?.description ?? extractedText);
    final tags = TextEditingController(text: existing?.tags.join(', ') ?? '');
    imagePath ??= existing?.imagePath;
    var category = existing?.category ?? (imagePath == null ? 'Notes' : 'Documents');
    final created = await showDialog<LibraryItem>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        scrollable: true,
        title: Text(existing != null ? 'Edit item' : (imagePath == null ? 'Create note' : 'Add to library')),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (imagePath != null || existing?.imageUrl != null) ClipRRect(borderRadius: BorderRadius.circular(14), child: imagePath != null ? Image.file(File(imagePath), height: 150, width: double.infinity, fit: BoxFit.cover) : Image.network(existing!.imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover)),
          if (imagePath != null || existing?.imageUrl != null) const SizedBox(height: 14),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: ['Documents', 'Screenshots', 'Receipts', 'Notes', 'Links'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setDialogState(() => category = value ?? category)),
          const SizedBox(height: 12),
          TextField(controller: tags, decoration: const InputDecoration(labelText: 'Tags', hintText: 'university, important')),
          const SizedBox(height: 12),
          TextField(controller: description, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: Platform.isAndroid && imagePath != null ? 'OCR text / description' : 'Description', alignLabelWithHint: true)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (title.text.trim().isEmpty) return;
            final style = _categoryStyle(category);
            Navigator.pop(context, LibraryItem(title: title.text.trim(), category: category, description: description.text.trim(), date: existing?.date ?? 'Just now', icon: style.$1, color: style.$2, tags: tags.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(), favorite: existing?.favorite ?? false, imagePath: imagePath, id: existing?.id, storagePath: existing?.storagePath, imageUrl: existing?.imageUrl));
          }, child: const Text('Save')),
        ],
      )),
    );
    // Android keeps text fields alive briefly during the dialog exit animation.
    // Delay disposal so the keyboard and inherited widgets can detach safely.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      title.dispose();
      description.dispose();
      tags.dispose();
    });
    if (created == null || !mounted) return;
    setState(() => _index = 1);
    try {
      if (existing == null) {
        await _createCloudItem(created);
      } else {
        await _updateCloudItem(created);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes synchronized.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not synchronize item: $error')));
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.pageName, required this.desktop, required this.onSearch, required this.onCommand});
  final String pageName;
  final bool desktop;
  final VoidCallback onSearch;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? user?.email?.split('@').first ?? 'User';
    return Padding(
      padding: EdgeInsets.fromLTRB(desktop ? 32 : 20, 14, desktop ? 32 : 12, 10),
      child: Row(
        children: [
          if (!desktop) ...[const _Logo(size: 34), const SizedBox(width: 10)],
          Text(pageName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (desktop)
            SizedBox(
              width: 300,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, size: 20),
                    const SizedBox(width: 9),
                    const Expanded(child: Text('Search your space')),
                    Text('Ctrl K', style: Theme.of(context).textTheme.labelSmall),
                  ]),
                ),
              ),
            ),
          IconButton(tooltip: 'Command palette', onPressed: onCommand, icon: const Icon(Icons.bolt_rounded)),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'sign_out') _confirmSignOut(context);
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall)])),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'sign_out', child: Row(children: [Icon(Icons.logout_rounded), SizedBox(width: 12), Text('Sign out')])),
            ],
            child: CircleAvatar(radius: 17, child: Text(name.isEmpty ? 'U' : name[0].toUpperCase())),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.items, required this.onNavigate, required this.onAdd, required this.onEdit, required this.onDelete, required this.onToggleFavorite});
  final List<LibraryItem> items;
  final ValueChanged<int> onNavigate;
  final VoidCallback onAdd;
  final ValueChanged<LibraryItem> onEdit;
  final ValueChanged<LibraryItem> onDelete;
  final ValueChanged<LibraryItem> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 14, wide ? 32 : 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _WelcomeBanner(onSearch: () => onNavigate(2), onAdd: onAdd),
          const SizedBox(height: 24),
          Text('Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: wide ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: wide ? 1.8 : 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(icon: Icons.folder_rounded, value: '${items.length}', label: 'Total items', color: const Color(0xFF7C5CFC)),
              _StatCard(icon: Icons.image_rounded, value: '${items.where((item) => item.category == 'Screenshots').length}', label: 'Screenshots', color: const Color(0xFF45B6FE)),
              _StatCard(icon: Icons.favorite_rounded, value: '${items.where((item) => item.favorite).length}', label: 'Favorites', color: const Color(0xFFFF6B8A)),
              _StatCard(icon: Icons.sell_rounded, value: '${items.expand((item) => item.tags).toSet().length}', label: 'Tags', color: const Color(0xFF44D7B6)),
            ],
          ),
          const SizedBox(height: 26),
          Row(children: [
            Text('Recent items', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(onPressed: () => onNavigate(1), child: const Text('View all')),
          ]),
          const SizedBox(height: 8),
          if (wide)
            SizedBox(
              height: 220,
              child: Row(children: [for (final item in items.take(3)) Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: ItemCard(item: item, onEdit: onEdit, onDelete: onDelete, onToggleFavorite: onToggleFavorite)))]),
            )
          else
            ...items.take(3).map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemListTile(item: item, onEdit: onEdit, onDelete: onDelete, onToggleFavorite: onToggleFavorite))),
        ]),
      );
    });
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.onSearch, required this.onAdd});
  final VoidCallback onSearch;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? user?.email?.split('@').first ?? 'there';
    final firstName = fullName.trim().split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, const Color(0xFF5B8CFF)]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Wrap(
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$greeting, $firstName', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('Everything you need, in one space.', style: TextStyle(color: Colors.white70, fontSize: 15)),
          ]),
          Wrap(spacing: 10, children: [
            FilledButton.tonalIcon(onPressed: onSearch, icon: const Icon(Icons.search_rounded), label: const Text('Search')),
            FilledButton.tonalIcon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Quick add')),
          ]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.items, required this.onEdit, required this.onDelete, required this.onToggleFavorite});
  final List<LibraryItem> items;
  final ValueChanged<LibraryItem> onEdit;
  final ValueChanged<LibraryItem> onDelete;
  final ValueChanged<LibraryItem> onToggleFavorite;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String category = 'All';
  bool grid = true;
  @override
  Widget build(BuildContext context) {
    final filtered = category == 'All'
        ? widget.items
        : category == 'Favorites'
            ? widget.items.where((item) => item.favorite).toList()
            : widget.items.where((item) => item.category == category).toList();
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 760;
      final columns = constraints.maxWidth >= 1200 ? 3 : 2;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(desktop ? 32 : 20, 14, desktop ? 32 : 20, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${filtered.length} saved items', style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            IconButton(onPressed: () => setState(() => grid = !grid), icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded)),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final value in ['All', 'Favorites', 'Documents', 'Screenshots', 'Receipts', 'Notes', 'Links'])
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(value), selected: category == value, onSelected: (_) => setState(() => category = value))),
          ])),
          const SizedBox(height: 20),
          if (grid && desktop)
            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, childAspectRatio: 1.45, crossAxisSpacing: 14, mainAxisSpacing: 14),
              itemCount: filtered.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, index) => ItemCard(item: filtered[index], onEdit: widget.onEdit, onDelete: widget.onDelete, onToggleFavorite: widget.onToggleFavorite),
            )
          else
            ...filtered.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemListTile(item: item, onEdit: widget.onEdit, onDelete: widget.onDelete, onToggleFavorite: widget.onToggleFavorite))),
        ]),
      );
    });
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.onEdit, required this.onDelete, required this.onToggleFavorite});
  final LibraryItem item;
  final ValueChanged<LibraryItem> onEdit;
  final ValueChanged<LibraryItem> onDelete;
  final ValueChanged<LibraryItem> onToggleFavorite;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showItem(context, item, onEdit, onDelete, onToggleFavorite),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: item.color.withValues(alpha: .15), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: item.color)),
                const Spacer(),
                if (item.favorite) const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B8A), size: 20),
              ]),
              const Spacer(),
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 5),
              Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(children: [Text(item.category, style: TextStyle(color: item.color, fontWeight: FontWeight.w600, fontSize: 12)), const Spacer(), Text(item.date, style: Theme.of(context).textTheme.labelSmall)]),
            ]),
          ),
        ),
      );
}

class ItemListTile extends StatelessWidget {
  const ItemListTile({super.key, required this.item, required this.onEdit, required this.onDelete, required this.onToggleFavorite});
  final LibraryItem item;
  final ValueChanged<LibraryItem> onEdit;
  final ValueChanged<LibraryItem> onDelete;
  final ValueChanged<LibraryItem> onToggleFavorite;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () => _showItem(context, item, onEdit, onDelete, onToggleFavorite),
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: item.color.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, color: item.color)),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${item.category}  •  ${item.date}'),
          trailing: item.favorite ? const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B8A), size: 20) : const Icon(Icons.chevron_right_rounded),
        ),
      );
}

void _showItem(BuildContext context, LibraryItem item, ValueChanged<LibraryItem> onEdit, ValueChanged<LibraryItem> onDelete, ValueChanged<LibraryItem> onToggleFavorite) {
  showDialog<void>(context: context, builder: (context) => AlertDialog(
    icon: Icon(item.icon, color: item.color, size: 36),
    title: Text(item.title),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((item.imagePath != null && File(item.imagePath!).existsSync()) || item.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: item.imagePath != null && File(item.imagePath!).existsSync()
                  ? Image.file(File(item.imagePath!), height: 220, width: 480, fit: BoxFit.cover)
                  : Image.network(item.imageUrl!, height: 220, width: 480, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image_outlined, size: 42)))),
            ),
            const SizedBox(height: 16),
          ],
          if (item.description.isNotEmpty) Text(item.description),
          if (item.description.isNotEmpty) const SizedBox(height: 18),
          Wrap(spacing: 7, runSpacing: 7, children: item.tags.map((tag) => Chip(label: Text('#$tag'))).toList()),
          const SizedBox(height: 12),
          Text('Saved ${item.date}', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ),
    actions: [
      IconButton(tooltip: item.favorite ? 'Remove favorite' : 'Add favorite', onPressed: () { Navigator.pop(context); onToggleFavorite(item); }, icon: Icon(item.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: item.favorite ? const Color(0xFFFF6B8A) : null)),
      TextButton.icon(onPressed: () => _shareItem(context, item), icon: const Icon(Icons.share_rounded), label: const Text('Share')),
      TextButton.icon(onPressed: () { Navigator.pop(context); onDelete(item); }, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      FilledButton.icon(onPressed: () { Navigator.pop(context); onEdit(item); }, icon: const Icon(Icons.edit_rounded), label: const Text('Edit')),
    ],
  ));
}

Future<void> _shareItem(BuildContext context, LibraryItem item) async {
  final text = <String>[
    item.title,
    item.category,
    if (item.description.isNotEmpty) item.description,
    if (item.tags.isNotEmpty) item.tags.map((tag) => '#$tag').join(' '),
    'Shared from OneSpace',
  ].join('\n\n');
  final files = <XFile>[];
  HttpClient? client;
  try {
    if (item.imagePath != null && await File(item.imagePath!).exists()) {
      files.add(XFile(item.imagePath!));
    } else if (item.imageUrl != null) {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(item.imageUrl!));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('Image download failed (${response.statusCode})');
      final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
      final uriPath = Uri.parse(item.imageUrl!).path;
      final extension = uriPath.contains('.') ? uriPath.substring(uriPath.lastIndexOf('.')).split('/').first : '.jpg';
      final safeName = item.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
      final temporary = await getTemporaryDirectory();
      final file = File('${temporary.path}${Platform.pathSeparator}${safeName.isEmpty ? 'onespace_item' : safeName}$extension');
      await file.writeAsBytes(bytes, flush: true);
      files.add(XFile(file.path));
    }
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      title: item.title,
      subject: 'OneSpace: ${item.title}',
      text: text,
      files: files,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share this item: $error')));
  } finally {
    client?.close(force: true);
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller, required this.items, required this.onEdit, required this.onDelete, required this.onToggleFavorite});
  final TextEditingController controller;
  final List<LibraryItem> items;
  final ValueChanged<LibraryItem> onEdit;
  final ValueChanged<LibraryItem> onDelete;
  final ValueChanged<LibraryItem> onToggleFavorite;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.toLowerCase().trim();
    final results = widget.items.where((item) => '${item.title} ${item.category} ${item.description} ${item.tags.join(' ')}'.toLowerCase().contains(query)).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: widget.controller,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Search titles, tags, categories and extracted text…', suffixIcon: query.isEmpty ? null : IconButton(onPressed: () { widget.controller.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded))),
        ),
        const SizedBox(height: 18),
        if (query.isEmpty) ...[
          Text('Try searching for', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: ['passport', 'flutter', 'receipt', 'university'].map((term) => ActionChip(label: Text(term), onPressed: () { widget.controller.text = term; setState(() {}); })).toList()),
          const SizedBox(height: 30),
          const _SearchHint(),
        ] else ...[
          Text('${results.length} result${results.length == 1 ? '' : 's'} for “${widget.controller.text}”', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          if (results.isEmpty) const _EmptySearch() else ...results.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ItemListTile(item: item, onEdit: widget.onEdit, onDelete: widget.onDelete, onToggleFavorite: widget.onToggleFavorite))),
        ],
      ]))),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [
    Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary, size: 34), const SizedBox(width: 16),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Universal search', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)), SizedBox(height: 5), Text('One search finds matching titles, categories, tags and extracted document text.')])),
  ])));
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Column(children: [Icon(Icons.search_off_rounded, size: 50), SizedBox(height: 12), Text('No matching items found')])));
}

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final tools = [
      (Icons.qr_code_2_rounded, 'QR generator', 'Turn text or a link into a QR code', const Color(0xFF45B6FE), () => _qrGenerator(context)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 760;
      return SingleChildScrollView(padding: EdgeInsets.fromLTRB(desktop ? 32 : 20, 14, desktop ? 32 : 20, 30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Small tools. Zero distractions.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6), Text('Useful utilities built directly into your workspace.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: desktop ? 3 : 1, childAspectRatio: desktop ? 1.25 : 2.15, crossAxisSpacing: 14, mainAxisSpacing: 14),
          itemCount: tools.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (_, index) { final tool = tools[index]; return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: tool.$5, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: tool.$4.withValues(alpha: .15), borderRadius: BorderRadius.circular(13)), child: Icon(tool.$1, color: tool.$4)), const Spacer(), Text(tool.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(tool.$3, maxLines: 2, style: Theme.of(context).textTheme.bodySmall)])))); },
        ),
      ]));
    });
  }
}

void _qrGenerator(BuildContext context) {
  final input = TextEditingController(text: 'https://example.com');
  final qrBoundaryKey = GlobalKey();
  var value = input.text;
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerLeft, child: Text('QR generator', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: qrBoundaryKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: SizedBox.square(
                  dimension: 230,
                  child: QrImageView(
                    data: value.isEmpty ? 'OneSpace' : value,
                    version: QrVersions.auto,
                    size: 230,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: input,
              minLines: 2,
              maxLines: 4,
              onChanged: (text) => setDialogState(() => value = text),
              decoration: const InputDecoration(labelText: 'Text or URL', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: input.text));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR content copied.')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy content'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    final boundary = qrBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                    if (boundary == null) throw StateError('QR image is not ready');
                    final image = await boundary.toImage(pixelRatio: 3);
                    final data = await image.toByteData(format: ui.ImageByteFormat.png);
                    if (data == null) throw StateError('Could not create QR image');
                    if (!context.mounted) return;
                    final box = context.findRenderObject() as RenderBox?;
                    await SharePlus.instance.share(ShareParams(
                      title: 'OneSpace QR code',
                      text: input.text,
                      files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png')],
                      fileNameOverrides: const ['OneSpace_QR.png'],
                      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                    ));
                  } catch (error) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share QR code: $error')));
                  }
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share QR'),
              ),
            ]),
          ]),
          ),
        ),
      ),
    ),
  ).whenComplete(() => Future<void>.delayed(const Duration(milliseconds: 600), input.dispose));
}

void _comingSoon(BuildContext context, String name) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name will be connected in the next feature step.')));

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: const Text('Sign out of OneSpace?'),
      content: const Text('Your cloud data will remain safely stored and available the next time you sign in.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.logout_rounded), label: const Text('Sign out')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.themeMode, required this.onThemeChanged});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser!;
    final name = user.userMetadata?['full_name'] as String? ?? user.email?.split('@').first ?? 'OneSpace user';
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 30), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Column(children: [
    Card(child: Column(children: [
      ListTile(leading: CircleAvatar(child: Text(name.isEmpty ? 'U' : name[0].toUpperCase())), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(user.email ?? 'Synchronized OneSpace account')),
      const Divider(height: 1),
      SwitchListTile(secondary: const Icon(Icons.dark_mode_rounded), title: const Text('Dark mode'), subtitle: const Text('Use the dark OneSpace appearance'), value: themeMode == ThemeMode.dark, onChanged: (value) => onThemeChanged(value ? ThemeMode.dark : ThemeMode.light)),
    ])),
    const SizedBox(height: 14),
    const Card(child: Column(children: [
      ListTile(leading: Icon(Icons.cloud_done_rounded), title: Text('Cloud synchronization'), subtitle: Text('Private account data • Windows and Android'), trailing: Icon(Icons.check_circle_rounded)),
      Divider(height: 1),
      ListTile(leading: Icon(Icons.keyboard_rounded), title: Text('Command palette'), subtitle: Text('Press Ctrl + K on Windows'), trailing: Icon(Icons.chevron_right_rounded)),
      Divider(height: 1),
      ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('About OneSpace'), subtitle: Text('Version 1.0.0 prototype')),
    ])),
    const SizedBox(height: 18),
    SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: () => _confirmSignOut(context), icon: const Icon(Icons.logout_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Sign out of OneSpace')))),
  ]))));
  }
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.onSelected});
  final ValueChanged<int> onSelected;
  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  String query = '';
  final commands = const [
    (Icons.space_dashboard_rounded, 'Go to Home', 0),
    (Icons.folder_copy_rounded, 'Open Library', 1),
    (Icons.search_rounded, 'Search everything', 2),
    (Icons.auto_awesome_rounded, 'Open Quick Tools', 3),
    (Icons.add_circle_outline_rounded, 'Add a new item', -2),
    (Icons.settings_rounded, 'Open Settings', 4),
  ];
  @override
  Widget build(BuildContext context) {
    final filtered = commands.where((command) => command.$2.toLowerCase().contains(query.toLowerCase())).toList();
    return Dialog(alignment: const Alignment(0, -.55), insetPadding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Padding(padding: const EdgeInsets.all(10), child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(autofocus: true, onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.bolt_rounded), hintText: 'Type a command…', border: InputBorder.none)),
      const Divider(height: 1),
      for (final command in filtered) ListTile(leading: Icon(command.$1), title: Text(command.$2), onTap: () => widget.onSelected(command.$3), trailing: const Icon(Icons.keyboard_return_rounded, size: 17)),
      if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No matching command')),
    ]))));
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFF4E9BFF)]), borderRadius: BorderRadius.circular(size * .32)), child: Icon(Icons.all_inclusive_rounded, color: Colors.white, size: size * .62));
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 19), label: Text(label), onPressed: onTap, padding: const EdgeInsets.all(10));
}
