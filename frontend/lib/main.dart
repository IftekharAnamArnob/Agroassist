import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(const AgroAssistApp());
}

class AgroAssistApp extends StatelessWidget {
  const AgroAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgroAssist',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedCrop;
  final String baseUrl =
    'https://connected-kept-rank-sixth.trycloudflare.com';

  List<String> crops = [];
  bool isLoadingCrops = true;
  List<String> diseases = [];
  bool isLoadingDiseases = false;
  List<String> selectedDiseases = [];
  XFile? selectedImage;
  final ImagePicker imagePicker = ImagePicker();
  bool isDiagnosing = false;
  String? prediction;
  String? explanation;
  String? errorMessage;

  Future<void> pickImage(ImageSource source) async {
    final XFile? image = await imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        selectedImage = image;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadCrops();
  }

  Future<void> loadCrops() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/crops'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          crops = List<String>.from(data['crops']);
          isLoadingCrops = false;
        });
      } else {
        setState(() {
          isLoadingCrops = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingCrops = false;
      });
    }
  }

  Future<void> loadDiseases(String crop) async {
    setState(() {
      isLoadingDiseases = true;
      diseases = [];
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/diseases/$crop'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loadedDiseases = List<String>.from(data['diseases']);

        setState(() {
          diseases = loadedDiseases;

          if (loadedDiseases.length <= 5) {
            selectedDiseases = List<String>.from(loadedDiseases);
          } else {
            selectedDiseases = [];
          }

          isLoadingDiseases = false;
        });
      } else {
        setState(() {
          isLoadingDiseases = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingDiseases = false;
      });
    }
  }

  Future<void> diagnoseDisease() async {
    if (selectedCrop == null ||
        selectedImage == null ||
        selectedDiseases.isEmpty) {
      return;
    }

    setState(() {
      isDiagnosing = true;
      prediction = null;
      explanation = null;
      errorMessage = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict'),
      );

      request.fields['crop'] = selectedCrop!;
      request.fields['candidates'] = selectedDiseases.join(',');

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          selectedImage!.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          prediction = data['prediction'];
          explanation = data['explanation'];
          isDiagnosing = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Prediction failed. Status code: ${response.statusCode}';
          isDiagnosing = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Could not connect to the prediction server.';
        isDiagnosing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AgroAssist',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            const Icon(
              Icons.eco,
              size: 48,
              color: Colors.green,
            ),

            const SizedBox(height: 12),

            const Text(
              'AI-Powered Plant Disease Identification',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Select a crop, upload a plant image, and let AgroAssist analyze the possible disease.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.agriculture,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Select Crop',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    isLoadingCrops
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : DropdownButtonFormField<String>(
                            value: selectedCrop,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Choose a crop',
                              prefixIcon: Icon(Icons.eco_outlined),
                            ),
                            items: crops.map((crop) {
                              return DropdownMenuItem<String>(
                                value: crop,
                                child: Text(crop),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCrop = value;
                                selectedDiseases = [];
                              });

                              if (value != null) {
                                loadDiseases(value);
                              }
                            },
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (isLoadingDiseases)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (diseases.isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.medical_information_outlined,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Possible Diseases',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${selectedDiseases.length}/${diseases.length <= 5 ? diseases.length : 5}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        diseases.length <= 5
                            ? 'All available diseases for this crop are selected automatically.'
                            : 'Select up to 5 suspected diseases.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (diseases.length <= 5)
                        ...diseases.map(
                          (disease) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            title: Text(disease),
                          ),
                        )
                      else
                        ...diseases.map(
                          (disease) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(disease),
                            value: selectedDiseases.contains(disease),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  if (selectedDiseases.length < 5) {
                                    selectedDiseases.add(disease);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'You can select up to 5 diseases only.',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  selectedDiseases.remove(disease);
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (selectedDiseases.isNotEmpty) ...[
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.green.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Candidates Considered',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        selectedDiseases.join(', '),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Plant Image',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                            ),
                          ),
                        ],
                      ),

                      if (selectedImage != null) ...[
                        const SizedBox(height: 14),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedImage!.path),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          selectedImage!.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (selectedCrop != null &&
                          selectedImage != null &&
                          selectedDiseases.isNotEmpty)
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      (selectedCrop != null &&
                              selectedImage != null &&
                              selectedDiseases.isNotEmpty)
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: (selectedCrop != null &&
                              selectedImage != null &&
                              selectedDiseases.isNotEmpty)
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        (selectedCrop != null &&
                                selectedImage != null &&
                                selectedDiseases.isNotEmpty)
                            ? 'Ready for AI analysis'
                            : 'Select a crop, disease candidates, and plant image to continue.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (selectedCrop != null &&
                          selectedImage != null &&
                          selectedDiseases.isNotEmpty &&
                          !isDiagnosing)
                      ? diagnoseDisease
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isDiagnosing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: Text(
                    isDiagnosing
                        ? 'Analyzing Plant...'
                        : 'Diagnose Disease',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (prediction != null) ...[
                const SizedBox(height: 20),

                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Diagnosis Result',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 28),

                        Text(
                          'Identified Disease',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          prediction!,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),

                        if (selectedCrop != null) ...[
                          const SizedBox(height: 8),

                          Text(
                            'Crop: $selectedCrop',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        if (explanation != null &&
                            explanation!.isNotEmpty) ...[
                          const SizedBox(height: 18),

                          const Text(
                            'AI Analysis',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            explanation!,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'AI-assisted identification. Verify important decisions with an agricultural professional.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedCrop = null;
                              diseases = [];
                              selectedDiseases = [];
                              selectedImage = null;
                              prediction = null;
                              explanation = null;
                              errorMessage = null;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Start New Diagnosis',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(
                              color: Colors.green.shade700,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Column(
                children: [
                  Divider(
                    color: Colors.grey.shade300,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'AgroAssist',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'AI-powered crop disease identification prototype',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Prototype v1.0',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
          ],
        ),
      ),
    );
  }
}