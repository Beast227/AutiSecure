import 'package:flutter/material.dart';

class LiveChat2 extends StatefulWidget {
  const LiveChat2({super.key});

  @override
  State<LiveChat2> createState() => _LiveChat2State();
}

class _LiveChat2State extends State<LiveChat2> {
  bool isChatOpen = false;
  String selectedUser = '';

  final List<Map<String, String>> requests = [
    {"name": "John Doe", "issue": "Consultation"},
    {"name": "Amar Singh", "issue": "Follow-up"},
    {"name": "Samar Verma", "issue": "Prescription Request"},
    {"name": "Fernandis", "issue": "New Appointment"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      floatingActionButton: !isChatOpen ? _buildFloatingButton() : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isChatOpen ? _buildChatWindow() : _buildChatList(),
        ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    int pendingCount = requests.length;

    return Stack(
      children: [
        FloatingActionButton(
          backgroundColor: Colors.orange.shade700,
          onPressed: _showExpandableSheet,
          child: const Icon(Icons.add, size: 40, color: Colors.white),
        ),
        if (pendingCount > 0)
          Positioned(
            right: -1,
            top: -7,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showExpandableSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (context, scrollController) {
            // Track expanded items
            List<bool> expanded = List.generate(requests.length, (_) => false);

            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Requests",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange.shade700,
                                      child: Text(
                                        req['name']![0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(req['name']!),
                                    subtitle: Text(req['issue']!),
                                    trailing: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade700,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      label: const Text(
                                        "More",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.info_outline,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setModalState(() {
                                          expanded[index] = !expanded[index];
                                        });
                                      },
                                    ),
                                  ),

                                  // Expanded section with more info
                                  if (expanded[index])
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      color: Colors.orange.shade50,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Patient: ${req['name']}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Issue: ${req['issue']}",
                                            style: const TextStyle(),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Additional info: Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 🧾 Chat List
  Widget _buildChatList() {
    final users = ['John', 'Amar', 'Samar', 'Fernandis'];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          color: Colors.white,
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.orange.shade200,
              child: Text(
                user[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A2500),
                ),
              ),
            ),
            title: Text(
              user,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A2500),
              ),
            ),
            subtitle: const Text(
              "Tap to start chatting",
              style: TextStyle(color: Colors.black54),
            ),
            trailing: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFFFF7A00),
            ),
            onTap: () {
              setState(() {
                isChatOpen = true;
                selectedUser = user;
              });
            },
          ),
        );
      },
    );
  }

  // 💬 Chat Window
  Widget _buildChatWindow() {
    return Column(
      children: [
        // App bar style header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 243, 167, 75),
                const Color.fromARGB(255, 243, 128, 51),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 255, 192, 192),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconButton(
                onPressed:
                    () => setState(() {
                      isChatOpen = false;
                    }),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Text(
                  selectedUser[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF5A2500),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                selectedUser,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              image: const DecorationImage(
                image: AssetImage('assets/logo.png'),
                fit: BoxFit.cover,
                opacity: 0.05,
              ),
            ),
            child: ListView.builder(
              itemCount: 20,
              reverse: true,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                bool isMe = index % 2 == 0;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isMe
                              ? Colors.orange.shade300
                              : Colors.orange.shade100,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            isMe ? const Radius.circular(16) : Radius.zero,
                        bottomRight:
                            isMe ? Radius.zero : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange,
                          blurRadius: 3,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isMe ? 'Hello!' : 'Hey, how are you?',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.orange,
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.emoji_emotions_outlined,
                color: Colors.orange.shade700,
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Type your message...",
                    hintStyle: TextStyle(color: Colors.orange.shade400),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (text) {},
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
