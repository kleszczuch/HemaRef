import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserSearchResult {
  final String uid;
  final String name;
  final String club;

  const UserSearchResult({
    required this.uid,
    required this.name,
    required this.club,
  });
}

class UserSearchDialog extends StatefulWidget {
  final Set<String> excludeUids;
  final String title;
  final bool friendsOnly;

  const UserSearchDialog({
    super.key,
    this.excludeUids = const {},
    this.title = 'Wybierz zawodnika',
    this.friendsOnly = false,
  });

  @override
  State<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<UserSearchDialog> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allUsers = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered = [];
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users;

    if (widget.friendsOnly) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      final friendsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .get();
      final friendUids = friendsSnap.docs
          .map((d) => d.id)
          .where((uid) => !widget.excludeUids.contains(uid))
          .toList();
      if (friendUids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _allUsers = [];
          _filtered = [];
          _loading = false;
        });
        return;
      }
      // Firestore 'whereIn' accepts max 30 elements per query
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> result = [];
      for (var i = 0; i < friendUids.length; i += 30) {
        final chunk = friendUids.sublist(
            i, i + 30 > friendUids.length ? friendUids.length : i + 30);
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        result.addAll(snap.docs);
      }
      users = result;
    } else {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      users = snapshot.docs
          .where((doc) => !widget.excludeUids.contains(doc.id))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _allUsers = users;
      _filtered = users;
      _loading = false;
    });
  }

  void _filter(String query) {
    final q = query.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allUsers;
      } else {
        _filtered = _allUsers.where((doc) {
          final data = doc.data();
          final name = (data['displayName'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final club = (data['chosenClub'] ?? '').toString().toLowerCase();
          return name.contains(q) || email.contains(q) || club.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Szukaj po nazwie, emailu lub klubie...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('Brak wyników',
                            style: TextStyle(fontSize: 16)))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final data = _filtered[index].data();
                          final name = data['displayName'] ??
                              data['email'] ??
                              _filtered[index].id;
                          final club = data['chosenClub'] ?? '';
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(name.toString()),
                            subtitle:
                                club.toString().isNotEmpty
                                    ? Text(club.toString())
                                    : null,
                            onTap: () {
                              Navigator.pop(
                                context,
                                UserSearchResult(
                                  uid: _filtered[index].id,
                                  name: name.toString(),
                                  club: club.toString(),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
