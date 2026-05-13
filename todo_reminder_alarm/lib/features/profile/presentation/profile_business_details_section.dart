part of 'profile_screen.dart';

extension _ProfileBusinessDetailsSection on _ProfileScreenState {
  Widget _buildBusinessDetailsSection({
    required BusinessProfile business,
    required _ProfileUiState uiState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: (uiState.businessLogoUrl ?? '').isNotEmpty
                  ? NetworkImage(uiState.businessLogoUrl!)
                  : null,
              child: (uiState.businessLogoUrl ?? '').isEmpty
                  ? const Icon(Icons.store, size: 36)
                  : null,
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: uiState.uploadingBusinessLogo
                  ? null
                  : () => _pickAndUploadBusinessLogo(business.id),
              icon: uiState.uploadingBusinessLogo
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: const Text('Upload Business Logo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _businessNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Business Name'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter business name'
              : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _businessCategoryController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Category'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter business category'
              : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _businessAddressController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Business Address'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _businessCityController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'City'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter city' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _businessGstController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Tax Registration Number',
            hintText: 'e.g. 27ABCDE1234F1Z5',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedTaxLabel,
          decoration: const InputDecoration(labelText: 'Tax Label'),
          items: _ProfileScreenState._taxLabelOptions
              .map(
                (label) =>
                    DropdownMenuItem<String>(value: label, child: Text(label)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            _selectedTaxLabel = value;
            _updateUi(
              (state) => state.copyWith(refreshTick: state.refreshTick + 1),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 132,
              child: InkWell(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: true,
                    onSelect: (country) {
                      _updateUi(
                        (state) => state.copyWith(businessCountry: country),
                      );
                    },
                  );
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Code'),
                  child: Text(
                    '${uiState.businessCountry.flagEmoji} +${uiState.businessCountry.phoneCode}',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _businessPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Business Contact Number',
                  hintText: '9876543210',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _businessDescriptionController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Business Description'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _selectedFiscalYearStartMonth ?? 4,
          decoration: const InputDecoration(
            labelText: 'Financial Year Start Month',
            helperText: 'Used for future order number reset',
          ),
          items: List.generate(12, (index) {
            final month = index + 1;
            return DropdownMenuItem<int>(
              value: month,
              child: Text(_monthLabels[index]),
            );
          }),
          onChanged: (value) {
            _selectedFiscalYearStartMonth = value ?? 4;
            _updateUi(
              (state) => state.copyWith(refreshTick: state.refreshTick + 1),
            );
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _businessShareLinkController,
          onChanged: (_) => _updateUi(
            (state) => state.copyWith(refreshTick: state.refreshTick + 1),
          ),
          decoration: const InputDecoration(
            labelText: 'Business Share Link',
            hintText: 'https://your-business-link.com',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _businessShareLinkController.text.trim().isEmpty
                ? null
                : () => _copyToClipboard(
                    'Business share link',
                    _businessShareLinkController.text,
                  ),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Business Link'),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PublicBusinessProfileScreen(
                    business: _buildPreviewBusiness(business, uiState),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.remove_red_eye_outlined),
            label: const Text('View Public Profile'),
          ),
        ),
      ],
    );
  }

  BusinessProfile _buildPreviewBusiness(
    BusinessProfile business,
    _ProfileUiState uiState,
  ) {
    return BusinessProfile(
      id: business.id,
      name: _businessNameController.text.trim().isEmpty
          ? business.name
          : _businessNameController.text.trim(),
      category: _businessCategoryController.text.trim().isEmpty
          ? business.category
          : _businessCategoryController.text.trim(),
      ownerId: business.ownerId,
      city: _businessCityController.text.trim().isEmpty
          ? business.city
          : _businessCityController.text.trim(),
      address: _businessAddressController.text.trim().isEmpty
          ? business.address
          : _businessAddressController.text.trim(),
      gstNumber: _businessGstController.text.trim().isEmpty
          ? business.gstNumber
          : _businessGstController.text.trim().toUpperCase(),
      taxLabel: _selectedTaxLabel,
      status: business.status,
      description: _businessDescriptionController.text.trim().isEmpty
          ? business.description
          : _businessDescriptionController.text.trim(),
      phone: _businessPhoneController.text.trim().isEmpty
          ? business.phone
          : _businessPhoneController.text.trim(),
      ownerPhone: _phoneController.text.trim().isEmpty
          ? business.ownerPhone
          : _phoneController.text.trim(),
      fiscalYearStartMonth:
          _selectedFiscalYearStartMonth ??
          business.resolvedFiscalYearStartMonth,
      logoUrl: (uiState.businessLogoUrl ?? '').trim().isEmpty
          ? business.logoUrl
          : uiState.businessLogoUrl,
      shareLink: _businessShareLinkController.text.trim().isEmpty
          ? business.shareLink
          : _businessShareLinkController.text.trim(),
      createdAt: business.createdAt,
    );
  }
}
