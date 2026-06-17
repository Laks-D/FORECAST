import re

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'r') as f:
    content = f.read()

# I will replace _ProfileStatsCard with a simplified version that just returns a Container or simple stats without `_paymentStatusFor`
new_card = """class _ProfileStatsCard extends StatelessWidget {
  final Client entity;

  const _ProfileStatsCard({required this.entity});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
"""

# Regex to match the entire _ProfileStatsCard class
content = re.sub(r"class _ProfileStatsCard extends StatelessWidget \{.*?\n\}\n(?=\n/\* ================= STATS ROW)", new_card, content, flags=re.DOTALL)
# Wait, the end marker might be `class _StatRow`
content = re.sub(r"class _ProfileStatsCard extends StatelessWidget \{.*?\n\}\n(?=\nclass _StatRow)", new_card, content, flags=re.DOTALL)

with open('lib/features/client/presentation/pages/client_profile_page.dart', 'w') as f:
    f.write(content)
