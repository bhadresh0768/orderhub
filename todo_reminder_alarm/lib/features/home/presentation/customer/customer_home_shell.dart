part of 'customer_home.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value;
    if (authState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profileAsync = ref.watch(userProfileProvider(authState.uid));
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('No profile found')));
        }
        return _CustomerHomeBody(profile: profile);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(child: Text('Something went wrong. Please retry.')),
      ),
    );
  }
}

class _CustomerHomeBody extends ConsumerStatefulWidget {
  const _CustomerHomeBody({required this.profile});

  final AppUser profile;

  @override
  ConsumerState<_CustomerHomeBody> createState() => _CustomerHomeBodyState();
}

