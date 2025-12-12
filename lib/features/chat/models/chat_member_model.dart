class ChatMember {
  final String name;
  final String status; 
  final String? avatarUrl;
  final bool isMe;
  final bool isAdmin; 

  ChatMember({
    required this.name,
    required this.status,
    this.avatarUrl,
    required this.isMe,
    this.isAdmin = false,
  });
}