import 'dart:convert';
import 'package:autisecure/mainScreens/user/subScreen/appointment_page.dart';
import 'package:autisecure/services/api_service.dart';
import 'package:autisecure/widgets/doctor_card.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Make sure the path is correct

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  List<Map<String, dynamic>> _doctorsList = [];
  bool _isLoadingFirstLoad = true; // For initial loading indicator
  bool _isFetchingMore = false; // For pagination loading indicator
  bool _hasMoreDoctors = true; // Assume there's more data initially
  int _currentPage = 1; // Start with page 1
  final int _limit = 10; // Number of doctors per page
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDoctorsFromCacheAndFetch();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // --- Scroll Listener for Lazy Loading ---
  void _scrollListener() {
    // Check if scrolled to near the bottom
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isFetchingMore &&
        _hasMoreDoctors) {
      _fetchDoctors(isInitialLoad: false); // Fetch next page
    }
  }

  // --- Helper to safely show SnackBars ---
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.orangeAccent,
      ),
    );
  }

  // --- Caching and Data Fetching Logic ---

  Future<void> _loadDoctorsFromCacheAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDataString = prefs.getString('doctorsCache');

    // 1. Load from cache first
    if (cachedDataString != null) {
      try {
        final List<dynamic> cachedDynamicList = json.decode(cachedDataString);
        _doctorsList = cachedDynamicList.cast<Map<String, dynamic>>();
        if (mounted) {
          setState(
            () => _isLoadingFirstLoad = false,
          ); // Show cached data immediately
        }
      } catch (e) {
        debugPrint("Error decoding cached doctors: $e");
        await prefs.remove('doctorsCache'); // Clear corrupted cache
      }
    }

    // 2. Then, fetch the first page from network
    await _fetchDoctors(
      isInitialLoad: true,
      cachedDataString: cachedDataString,
    );
  }

  Future<void> _fetchDoctors({
    required bool isInitialLoad,
    String? cachedDataString,
  }) async {
    // Prevent multiple simultaneous fetches
    if (_isFetchingMore) return;

    if (mounted) {
      setState(() {
        if (isInitialLoad && _doctorsList.isEmpty) {
          _isLoadingFirstLoad = true;
        } else if (!isInitialLoad) {
          _isFetchingMore = true; // Show bottom loader
        }
        _error = null; // Clear previous errors on fetch attempt
      });
    }

    try {
      // Fetch using the updated ApiService method with named parameters
      final Map<String, dynamic> apiResponse = await ApiService.fetchDoctors(
        page: isInitialLoad ? 1 : _currentPage, // Pass page
        limit: _limit, // Pass limit
      );

      // Extract data correctly from the returned Map
      final List<Map<String, dynamic>> fetchedDoctors =
          apiResponse['doctors'] ?? []; // Correctly access the list
      final bool serverHasMore =
          apiResponse['hasMore'] ?? false; // Correctly access hasMore

      if (!mounted) return;

      if (isInitialLoad) {
        // Compare full fetched data (first page) with cache
        final String fetchedDataString = json.encode(fetchedDoctors);
        if (fetchedDataString != cachedDataString) {
          debugPrint("Doctor list (Page 1) mismatch. Updating cache and UI.");
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('doctorsCache', fetchedDataString);

          setState(() {
            _doctorsList = fetchedDoctors; // Replace list with first page
            _currentPage = 2; // Set up for the next fetch
            _hasMoreDoctors = serverHasMore;
            if (_doctorsList.isNotEmpty && cachedDataString != null) {
              _showSnackBar("Doctor list updated.");
            }
          });
        } else {
          debugPrint("Doctor list (Page 1) is up-to-date.");
          setState(() {
            _currentPage = 2;
            _hasMoreDoctors = serverHasMore;
          });
        }
      } else {
        // Append new doctors for pagination
        setState(() {
          _doctorsList.addAll(fetchedDoctors);
          _currentPage++;
          _hasMoreDoctors = serverHasMore;
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
      if (mounted) {
        setState(() {
          _error = "Failed to fetch doctors. Please check your connection.";
          if (isInitialLoad && _doctorsList.isEmpty) {
            _showSnackBar(_error!, isError: true);
          } else if (!isInitialLoad) {
            _showSnackBar("Could not load more doctors.", isError: true);
            _hasMoreDoctors = false;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFirstLoad = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.only(top: 15.0, left: 8.0, right: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: AppBar(
              automaticallyImplyLeading: false,
              title: const Text(
                "Find a Specialist",
                style: TextStyle(
                  fontFamily: "Merriweather",
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFFF5E3),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingFirstLoad) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (_error != null && _doctorsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_doctorsList.isEmpty) {
      return const Center(
        child: Text(
          "No doctors available right now.",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _doctorsList = [];
          _currentPage = 1;
          _hasMoreDoctors = true;
          _error = null;
        });
        // Refetch and clear cache implicitly by passing null
        await _fetchDoctors(isInitialLoad: true, cachedDataString: null);
      },
      color: Colors.orange,
      child: ListView.builder(
        controller: _scrollController,
        itemCount:
            _doctorsList.length + (_hasMoreDoctors ? 1 : 0), // +1 for loader
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        itemBuilder: (context, index) {
          if (index == _doctorsList.length) {
            return _buildLoaderItem();
          }

          final doctor = _doctorsList[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: DoctorCard(
              doctor: doctor,
              onBookPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentPage(doctor: doctor),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoaderItem() {
    return _isFetchingMore
        ? const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(color: Colors.orange),
          ),
        )
        // Only show "End of list" if we know there are no more doctors
        : !_hasMoreDoctors && _doctorsList.isNotEmpty
        ? const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Text(
              "You've reached the end of the list.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        )
        : const SizedBox.shrink(); // Show nothing otherwise
  }
}
