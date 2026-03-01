import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'settings.dart';
import 'loginPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _selectedWeapon;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppSettingsData>(context, listen: false).reloadFromFirebase();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _getCheckboxColor(Set<WidgetState> states) {
    const interactiveStates = <WidgetState>{
      WidgetState.pressed,
      WidgetState.hovered,
      WidgetState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Colors.blue;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj się',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<AppSettingsData>(
          builder: (context, appSettings, child) {
            final selectedWeapons = appSettings.categorySelections.entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toList();

            final int displayWins;
            final int displayLosses;
            final int displayDraws;
            final int displayYellowCards;
            final int displayRedCards;

            if (_selectedWeapon == null) {
              displayWins = appSettings.wins;
              displayLosses = appSettings.losses;
              displayDraws = appSettings.draws;
              displayYellowCards = appSettings.totalYellowCards;
              displayRedCards = appSettings.totalRedCards;
            } else {
              final weaponStat = appSettings.weaponStats[_selectedWeapon];
              displayWins = weaponStat?.wins ?? 0;
              displayLosses = weaponStat?.losses ?? 0;
              displayDraws = weaponStat?.draws ?? 0;
              displayYellowCards = weaponStat?.yellowCards ?? 0;
              displayRedCards = weaponStat?.redCards ?? 0;
            }

            final displayTotal = displayWins + displayLosses + displayDraws;
            final displayWinRate = displayTotal > 0
                ? (displayWins / displayTotal) * 100
                : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    appSettings.displayName.isNotEmpty
                        ? appSettings.displayName
                        : (user?.displayName ?? user?.email ?? 'Użytkownik'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user?.email != null)
                    Text(
                      user!.email!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 24),

                  // Zmiana nazwy
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wyświetlana nazwa',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nowa nazwa',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.edit),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () {
                                  if (_nameController.text.trim().isNotEmpty) {
                                    appSettings.updateDisplayName(
                                        _nameController.text.trim());
                                    _nameController.clear();
                                  }
                                },
                              ),
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                appSettings.updateDisplayName(value.trim());
                                _nameController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kategorie
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kategorie',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Wybierz kategorie w których startujesz',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const Divider(),
                          ...appSettings.categorySelections.entries.map(
                            (MapEntry<String, bool> entry) {
                              return CheckboxListTile(
                                title: Text(entry.key),
                                value: entry.value,
                                checkColor: Colors.white,
                                fillColor: WidgetStateProperty.resolveWith(
                                  _getCheckboxColor,
                                ),
                                onChanged: (bool? newValue) {
                                  if (newValue != null) {
                                    appSettings.setCategorySelected(
                                      entry.key,
                                      newValue,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Klub
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Klub',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          Text(
                            'Wybrany: ${appSettings.chosenClub}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return appSettings.club.where(
                                (club) => club.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase(),
                                ),
                              );
                            },
                            onSelected: (String selection) {
                              appSettings.chosenClub = selection;
                            },
                            fieldViewBuilder: (
                              BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                onFieldSubmitted: (String value) {
                                  onFieldSubmitted();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Szukaj klubu',
                                  border: OutlineInputBorder(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filtry broni
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtruj statystyki',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Wszystkie'),
                                selected: _selectedWeapon == null,
                                onSelected: (_) =>
                                    setState(() => _selectedWeapon = null),
                              ),
                              ...selectedWeapons.map((weapon) => ChoiceChip(
                                    label: Text(weapon),
                                    selected: _selectedWeapon == weapon,
                                    onSelected: (_) =>
                                        setState(() => _selectedWeapon = weapon),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedWeapon == null
                                ? 'Statystyki'
                                : 'Statystyki - $_selectedWeapon',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          _statRow('Zwycięstwa', '$displayWins'),
                          _statRow('Porażki', '$displayLosses'),
                          _statRow('Remisy', '$displayDraws'),
                          _statRow('Łącznie meczy', '$displayTotal'),
                          _statRow(
                            'Współczynnik zwycięstw',
                            '${displayWinRate.toStringAsFixed(1)}%',
                          ),
                          _statRow('Żółte kartki', '$displayYellowCards'),
                          _statRow('Czerwone kartki', '$displayRedCards'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
