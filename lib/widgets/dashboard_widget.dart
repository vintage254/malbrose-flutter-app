import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color.fromARGB(207, 162, 216, 176).withAlpha(179),
            const Color.fromARGB(207, 89, 226, 123),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Welcome to malbrose hardware and stores pos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'Roboto',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(221, 190, 169, 169),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: defaultPadding * 2),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search (Client, product, state, etc...)',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    Container(
                      padding: const EdgeInsets.all(defaultPadding),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Tooltip(
                              message: 'Image',
                              child: Text(
                                'Image',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 2,
                            child: Tooltip(
                              message: 'Supplier Name',
                              child: Text(
                                'Supplier Name',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 2,
                            child: Tooltip(
                              message: 'Date Ordered',
                              child: Text(
                                'Date Ordered',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 2,
                            child: Tooltip(
                              message: 'Delivering Date',
                              child: Text(
                                'Delivering Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 2,
                            child: Tooltip(
                              message: 'Product Name',
                              child: Text(
                                'Product Name',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 1,
                            child: Tooltip(
                              message: 'Serial NO.',
                              child: Text(
                                'Serial NO.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 1,
                            child: Tooltip(
                              message: 'Quantity',
                              child: Text(
                                'Quantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 1,
                            child: Tooltip(
                              message: 'Price',
                              child: Text(
                                'Price',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 1,
                            child: Tooltip(
                              message: 'Total',
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          VerticalDivider(
                              thickness: 1, indent: 8, endIndent: 8),
                          Expanded(
                            flex: 1,
                            child: Tooltip(
                              message: 'State',
                              child: Text(
                                'State',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    const Expanded(
                      child: Center(
                        child: Text('No records to display'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
