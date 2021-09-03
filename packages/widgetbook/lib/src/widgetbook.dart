import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/src/cubit/canvas/canvas_cubit.dart';
import 'package:widgetbook/src/cubit/device/device_cubit.dart';
import 'package:widgetbook/src/cubit/injected_theme/injected_theme_cubit.dart';
import 'package:widgetbook/src/cubit/categories/categories_cubit.dart';
import 'package:widgetbook/src/cubit/theme/theme_cubit.dart';
import 'package:widgetbook/src/cubit/zoom/zoom_cubit.dart';
import 'package:widgetbook/src/models/app_info.dart';
import 'package:widgetbook/src/models/device.dart';
import 'package:widgetbook/src/models/organizers/organizer_helper/organizer_helper.dart';
import 'package:widgetbook/src/models/organizers/organizers.dart';
import 'package:widgetbook/src/repository/story_repository.dart';
import 'package:widgetbook/src/routing/route_information_parser.dart';
import 'package:widgetbook/src/routing/story_router_delegate.dart';
import 'package:widgetbook/src/utils/utils.dart';
import 'configure_non_web.dart' if (dart.library.html) 'configure_web.dart';

class Widgetbook extends StatefulWidget {
  /// Categories which host Folders and WidgetElements.
  /// This can be used to organize the structure of the Widgetbook on a large scale.
  final List<Category> categories;

  /// The devices on which Stories are previewed.
  final List<Device> devices;

  /// Information about the app that is catalogued in the Widgetbook.
  final AppInfo appInfo;

  /// The `ThemeData` that is shown when the light theme is active.
  final ThemeData? lightTheme;

  /// The `ThemeData` that is shown when the dark theme is active.
  final ThemeData? darkTheme;

  const Widgetbook({
    required this.categories,
    this.devices = const [
      Apple.iPhone11,
      Apple.iPhone12,
      Apple.iPhone12mini,
      Apple.iPhone12pro,
      Samsung.s10,
      Samsung.s21ultra,
    ],
    required this.appInfo,
    this.lightTheme,
    this.darkTheme,
  });

  @override
  _WidgetbookState createState() => _WidgetbookState();
}

class _WidgetbookState extends State<Widgetbook> {
  late CategoriesCubit categoriesCubit;
  late DeviceCubit deviceCubit;
  late InjectedThemeCubit injectedThemeCubit;
  late StoryRepository storyRepository;

  @override
  void initState() {
    configureApp();
    storyRepository = StoryRepository();
    categoriesCubit = CategoriesCubit(
      categories: widget.categories,
      storyRepository: storyRepository,
    );
    deviceCubit = DeviceCubit(devices: widget.devices);
    injectedThemeCubit = InjectedThemeCubit(
      lightTheme: widget.lightTheme,
      darkTheme: widget.darkTheme,
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant Widgetbook oldWidget) {
    categoriesCubit.update(widget.categories);
    deviceCubit.update(widget.devices);
    injectedThemeCubit.themesChanged(
      lightTheme: widget.lightTheme,
      darkTheme: widget.darkTheme,
    );
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (context) => storyRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => CanvasCubit(
              storyRepository: context.read<StoryRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => ThemeCubit(),
          ),
          BlocProvider(
            create: (context) => ZoomCubit(),
          ),
          BlocProvider(
            create: (context) => categoriesCubit,
          ),
          BlocProvider(
            create: (context) => deviceCubit,
          ),
          BlocProvider(
            create: (context) => injectedThemeCubit,
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return BlocBuilder<CanvasCubit, CanvasState>(
              builder: (context, canvasState) {
                return BlocBuilder<CategoriesCubit, OrganizerState>(
                  builder: (context, storiesState) {
                    return MaterialApp.router(
                      routeInformationParser: StoryRouteInformationParser(
                        onRoute: (path) {
                          var stories = StoryHelper.getAllStoriesFromCategories(
                            storiesState.allCategories,
                          );
                          var selectedStory =
                              selectStoryFromPath(path, stories);
                          context
                              .read<CanvasCubit>()
                              .selectStory(selectedStory);
                        },
                      ),
                      routerDelegate: StoryRouterDelegate(
                        canvasState: canvasState,
                        appInfo: widget.appInfo,
                      ),
                      title: 'Firebook',
                      debugShowCheckedModeBanner: false,
                      themeMode: themeMode,
                      darkTheme: Styles.darkTheme,
                      theme: Styles.lightTheme,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Story? selectStoryFromPath(
    String? path,
    List<Story> stories,
  ) {
    String storyPath = path?.replaceFirst('/stories/', '') ?? '';
    Story? story;
    for (final element in stories) {
      if (element.path == storyPath) {
        story = element;
      }
    }
    return story;
  }
}
