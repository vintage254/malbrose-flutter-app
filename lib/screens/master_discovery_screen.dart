import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/master_discovery_service.dart';
import '../models/master_info_model.dart';
import '../widgets/app_scaffold.dart';

class MasterDiscoveryScreen extends StatefulWidget {
  static const String routeName = '/master-discovery';
  
  const MasterDiscoveryScreen({Key? key}) : super(key: key);

  @override
  State<MasterDiscoveryScreen> createState() => _MasterDiscoveryScreenState();
}

class _MasterDiscoveryScreenState extends State<MasterDiscoveryScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _scanningAnimationController;
  late Animation<double> _scanningAnimation;
  late Animation<double> _pulseAnimation;
  
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for scanning animation
    _scanningAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _scanningAnimation = Tween<double>(begin: 0, end: 1).animate(_scanningAnimationController);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _scanningAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start discovery automatically when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MasterDiscoveryService>(context, listen: false).startDiscovery();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _searchController.dispose();
    _scanningAnimationController.dispose();
    super.dispose();
  }
  
  List<MasterInfo> _getFilteredMasters(List<MasterInfo> masters) {
    if (_searchTerm.isEmpty) {
      return masters;
    }
    
    final searchLower = _searchTerm.toLowerCase();
    return masters.where((master) {
      final deviceName = master.deviceName?.toLowerCase() ?? '';
      final ip = master.ip.toLowerCase();
      final version = master.version?.toLowerCase() ?? '';
      
      return deviceName.contains(searchLower) || 
             ip.contains(searchLower) ||
             version.contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AppScaffold(
      title: 'Master Discovery',
      body: Consumer<MasterDiscoveryService>(
        builder: (context, discoveryService, child) {
          // Update animation state based on scanning status
          if (discoveryService.isScanning) {
            _scanningAnimationController.repeat();
          } else {
            _scanningAnimationController.stop();
            _scanningAnimationController.reset();
          }
          
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoBanner(discoveryService, colorScheme),
                const SizedBox(height: 24),
                _buildConnectionTypeSelector(discoveryService, colorScheme),
                const SizedBox(height: 20),
                _buildScanControls(discoveryService, colorScheme),
                const SizedBox(height: 20),
                _buildStatusIndicator(discoveryService, colorScheme),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildMasterList(discoveryService, colorScheme),
                ),
                const SizedBox(height: 20),
                _buildManualConnectionSection(discoveryService, colorScheme),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildInfoBanner(MasterDiscoveryService discoveryService, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Master Discovery',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Connect to a master device on your network to begin synchronization. Choose your connection type and scan for available masters.',
                  style: TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTypeSelector(MasterDiscoveryService discoveryService, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connection Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildConnectionTypeCard(
                discoveryService,
                ConnectionType.wifi,
                'WiFi',
                Icons.wifi,
                'Best for most setups',
                colorScheme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildConnectionTypeCard(
                discoveryService,
                ConnectionType.ethernet,
                'Ethernet',
                Icons.lan,
                'More stable connection',
                colorScheme,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildConnectionTypeCard(
    MasterDiscoveryService discoveryService,
    ConnectionType type,
    String label,
    IconData icon,
    String description,
    ColorScheme colorScheme,
  ) {
    final isSelected = discoveryService.connectionType == type;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => discoveryService.setConnectionType(type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.surface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.6),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanControls(MasterDiscoveryService discoveryService, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: discoveryService.isScanning
                ? null
                : () => discoveryService.startDiscovery(),
            icon: discoveryService.isScanning
                ? AnimatedBuilder(
                    animation: _scanningAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _scanningAnimation.value * 2 * 3.14159,
                        child: const Icon(Icons.sync),
                      );
                    },
                  )
                : const Icon(Icons.search),
            label: Text(
              discoveryService.isScanning ? 'Scanning...' : 'Scan for Masters',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(MasterDiscoveryService discoveryService, ColorScheme colorScheme) {
    final statusText = switch (discoveryService.status) {
      DiscoveryStatus.idle => 'Ready to scan',
      DiscoveryStatus.scanning => 'Scanning for masters on your network...',
      DiscoveryStatus.found => 'Found ${discoveryService.discoveredMasters.length} masters',
      DiscoveryStatus.failed => 'Scan failed: ${discoveryService.errorMessage}',
      DiscoveryStatus.connected => 'Connected to ${discoveryService.selectedMaster?.deviceName ?? discoveryService.selectedMaster?.ip}',
    };

    final icon = switch (discoveryService.status) {
      DiscoveryStatus.idle => Icons.info_outline,
      DiscoveryStatus.scanning => Icons.sync,
      DiscoveryStatus.found => Icons.check_circle_outline,
      DiscoveryStatus.failed => Icons.error_outline,
      DiscoveryStatus.connected => Icons.link,
    };

    final color = switch (discoveryService.status) {
      DiscoveryStatus.idle => Colors.grey,
      DiscoveryStatus.scanning => colorScheme.primary,
      DiscoveryStatus.found => Colors.green,
      DiscoveryStatus.failed => Colors.red,
      DiscoveryStatus.connected => Colors.green,
    };
    
    final subtitle = switch (discoveryService.status) {
      DiscoveryStatus.idle => 'Press "Scan" to search for masters',
      DiscoveryStatus.scanning => 'This may take a moment...',
      DiscoveryStatus.found => 'Select a master to connect',
      DiscoveryStatus.failed => 'Check network settings and try again',
      DiscoveryStatus.connected => 'Ready to synchronize',
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (discoveryService.status == DiscoveryStatus.scanning)
            AnimatedBuilder(
              animation: _scanningAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _scanningAnimation.value * 2 * 3.14159,
                  child: Icon(icon, color: color, size: 24),
                );
              },
            )
          else
            Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (discoveryService.status == DiscoveryStatus.scanning)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.2),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                          value: null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMasterList(MasterDiscoveryService discoveryService, ColorScheme colorScheme) {
    if (discoveryService.isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _scanningAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing outer circle
                      Transform.scale(
                        scale: 0.8 + (_pulseAnimation.value - 1.0) * 2,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withOpacity(0.1),
                          ),
                        ),
                      ),
                      // Middle circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withOpacity(0.15),
                        ),
                      ),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                      Transform.rotate(
                        angle: _scanningAnimation.value * 2 * 3.14159,
                        child: Icon(
                          Icons.wifi_find,
                          color: colorScheme.primary,
                          size: 30,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Searching for masters on your network...',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This may take a few moments',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    final filteredMasters = _getFilteredMasters(discoveryService.discoveredMasters);

    if (discoveryService.discoveredMasters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No masters found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Make sure your master device is turned on and connected to the same network',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => discoveryService.startDiscovery(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Discovered Masters (${discoveryService.discoveredMasters.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => discoveryService.startDiscovery(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Rescan'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Search field for filtering masters
        if (discoveryService.discoveredMasters.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter masters...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchTerm = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value;
                });
              },
            ),
          ),
        // Display filter results summary if filtering is active
        if (_searchTerm.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Showing ${filteredMasters.length} of ${discoveryService.discoveredMasters.length} masters',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredMasters.length,
            itemBuilder: (context, index) {
              final master = filteredMasters[index];
              return _buildMasterListItem(master, discoveryService, colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMasterListItem(MasterInfo master, MasterDiscoveryService discoveryService, ColorScheme colorScheme) {
    final isSelected = discoveryService.selectedMaster?.ip == master.ip;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => discoveryService.selectMaster(master),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.surface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isSelected 
                        ? colorScheme.primary.withOpacity(0.5)
                        : colorScheme.onSurface.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.computer,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      master.deviceName ?? 'Unknown Device',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.lan,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          master.ip,
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    if (master.version != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Version: ${master.version}',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (master.signalStrength != null) ...[
                _buildSignalStrengthIndicator(master.signalStrength!, colorScheme),
                const SizedBox(width: 16),
              ],
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Connected',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => discoveryService.selectMaster(master),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: colorScheme.onPrimary,
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Connect'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalStrengthIndicator(int strength, ColorScheme colorScheme) {
    IconData icon;
    Color color;
    
    if (strength > 80) {
      icon = Icons.network_wifi;
      color = Colors.green;
    } else if (strength > 60) {
      icon = Icons.network_wifi;
      color = Colors.green;
    } else if (strength > 40) {
      icon = Icons.network_wifi;
      color = Colors.orange;
    } else if (strength > 20) {
      icon = Icons.network_wifi;
      color = Colors.red;
    } else {
      icon = Icons.signal_wifi_off;
      color = Colors.red;
    }
    
    // Create a gradient background for the signal indicator
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.7),
        color.withOpacity(0.3),
      ],
    );
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            '$strength%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualConnectionSection(MasterDiscoveryService discoveryService, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Manual Connection',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'If your master device is not discovered automatically, you can connect using its IP address',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Master IP Address',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.lan),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: discoveryService.isScanning
                    ? null
                    : () {
                        final ip = _ipController.text.trim();
                        if (ip.isNotEmpty) {
                          discoveryService.connectToMaster(ip);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  foregroundColor: colorScheme.onPrimary,
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Connect'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignalStrengthIcon(int signalStrength) {
    if (signalStrength >= 80) {
      return Icon(Icons.network_wifi, color: Colors.green);
    } else if (signalStrength >= 60) {
      return Icon(Icons.network_wifi, color: Colors.green);
    } else if (signalStrength >= 40) {
      return Icon(Icons.network_wifi, color: Colors.orange);
    } else if (signalStrength >= 20) {
      return Icon(Icons.network_wifi, color: Colors.orange);
    } else {
      return Icon(Icons.signal_wifi_off, color: Colors.red);
    }
  }
}