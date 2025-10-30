import 'dart:convert';
// import 'package:autisecure/mainScreens/user/subScreen/appointment_page.dart'; // No longer needed
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Ensure correct paths
import '../../services/api_service.dart';
import '../../widgets/doctor_card.dart';

// Renamed class
class DocDocListScreen extends StatefulWidget {
  const DocDocListScreen({super.key});

  @override
  // Renamed state class
  State<DocDocListScreen> createState() => _DocDocListScreenState();
}

// Renamed state class
class _DocDocListScreenState extends State<DocDocListScreen> {
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
    final cachedDataString = prefs.getString('doctorsCache'); // Use consistent cache key

    // 1. Load from cache first
    if (cachedDataString != null) {
      try {
        final List<dynamic> cachedDynamicList = json.decode(cachedDataString);
        _doctorsList = cachedDynamicList.cast<Map<String, dynamic>>();
        if (mounted) {
          setState(() =>
              _isLoadingFirstLoad = false); // Show cached data immediately
        }
      } catch (e) {
        debugPrint("Error decoding cached doctors: $e");
        await prefs.remove('doctorsCache'); // Clear corrupted cache
      }
    }

    // 2. Then, fetch the first page from network
    await _fetchDoctors(isInitialLoad: true, cachedDataString: cachedDataString);
  }

  Future<void> _fetchDoctors(
      {required bool isInitialLoad, String? cachedDataString}) async {
    // Prevent multiple simultaneous fetches
    if (_isFetchingMore) return;

    if (mounted) {
      setState(() {
        if (isInitialLoad && _doctorsList.isEmpty) { // Only show full screen load if cache was empty
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
        limit: _limit,                           // Pass limit
      );

      // Extract data correctly from the returned Map
      final List<Map<String, dynamic>> fetchedDoctors =
          apiResponse['doctors'] ?? []; // Correctly access the list
      final bool serverHasMore = apiResponse['hasMore'] ?? false; // Correctly access hasMore


      if (!mounted) return;

      if (isInitialLoad) {
        // Compare full fetched data (first page) with cache
        final String fetchedDataString = json.encode(fetchedDoctors);
        if (fetchedDataString != cachedDataString) {
          debugPrint("Doctor list (Page 1) mismatch. Updating cache and UI.");
          final prefs = await SharedPreferences.getInstance();
          // Cache only the first page for fast initial load
          await prefs.setString('doctorsCache', fetchedDataString);

          setState(() {
            _doctorsList = fetchedDoctors; // Replace list with first page
            _currentPage = 2; // Set up for the next fetch
            _hasMoreDoctors = serverHasMore;
             if (_doctorsList.isNotEmpty && cachedDataString != null){ // Show update snackbar only if cache existed
               _showSnackBar("Doctor list updated.");
             }
          });
        } else {
           debugPrint("Doctor list (Page 1) is up-to-date.");
           // Even if cache is same, ensure pagination state is correct
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
          // Show error prominently only if it's the first load and cache failed
           if (isInitialLoad && _doctorsList.isEmpty) {
             _showSnackBar(_error!, isError: true);
           } else if (!isInitialLoad){
             // For pagination errors, maybe just a subtle snackbar
              _showSnackBar("Could not load more doctors.", isError: true);
              _hasMoreDoctors = false; // Stop trying to fetch more on error
           }
        });
      }
    } finally {
      // Ensure loading indicators are turned off
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
        preferredSize: const Size.fromHeight(70), // Slightly taller
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: AppBar(
              automaticallyImplyLeading: false, // Remove back button if needed
              title: const Text(
                "Find a Specialist", // More professional title
                style: TextStyle(
                  fontFamily: "Merriweather",
                  color: Color(0xFFB97001), // Darker orange for better contrast
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 2, // Add subtle shadow
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFFF5E3), // Lighter background
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingFirstLoad) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (_error != null && _doctorsList.isEmpty) {
      // Show prominent error only if the list is empty
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column( // Use Column for icon, text, and button
            mainAxisSize: MainAxisSize.min,
            children: [
               Icon(Icons.cloud_off, color: Colors.red.shade300, size: 50),
               const SizedBox(height: 10),
               Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
               ),
               const SizedBox(height: 20),
               ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  onPressed: () { // Retry logic
                      setState(() {
                         _doctorsList = [];
                         _currentPage = 1;
                         _hasMoreDoctors = true;
                         _error = null;
                      });
                      _loadDoctorsFromCacheAndFetch();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                )
            ],
          ),
        ),
      );
    }

    if (_doctorsList.isEmpty) {
      return Center(
        child: Column( // Use Column for text and refresh icon
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text(
                "No doctors available right now.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
             ),
              const SizedBox(height: 20),
               IconButton(
                icon: const Icon(Icons.refresh, size: 30, color: Colors.orange),
                tooltip: "Refresh",
                onPressed: () async { // Refresh logic
                      setState(() {
                         _doctorsList = [];
                         _currentPage = 1;
                         _hasMoreDoctors = true;
                         _error = null;
                      });
                      await _fetchDoctors(isInitialLoad: true, cachedDataString: null);
                   },
              ),
          ],
        )
      );
    }

    // Main List View for doctors
    return RefreshIndicator( // Added pull-to-refresh
       onRefresh: () async {
         setState(() {
           _doctorsList = []; // Clear list for refresh
           _currentPage = 1;
           _hasMoreDoctors = true;
           _error = null;
         });
         await _fetchDoctors(isInitialLoad: true, cachedDataString: null);
       },
       color: Colors.orange,
       child: ListView.builder(
        controller: _scrollController,
        itemCount: _doctorsList.length + (_hasMoreDoctors ? 1 : 0), // +1 for loader
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        itemBuilder: (context, index) {
          // Check if it's the loader item
          if (index == _doctorsList.length) {
            return _buildLoaderItem();
          }

          // It's a doctor item
          final doctor = _doctorsList[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0), // Spacing between cards
            // --- MODIFICATION HERE ---
            child: DoctorCard(
              doctor: doctor,
              // Pass null or an empty function to onBookPressed,
              // or modify DoctorCard to hide the button if onBookPressed is null.
              // Assuming DoctorCard can handle a null callback:
              onBookPressed: null,
            ),
            // --- END MODIFICATION ---
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