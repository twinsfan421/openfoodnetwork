require 'spec_helper'

module Api
  describe ProductImagesController, type: :controller do
    include AuthenticationWorkflow
    render_views

    describe "uploading an image" do
      before do
        allow(controller).to receive(:spree_current_user) { current_api_user }
      end

      image_path = File.open(Rails.root.join('app', 'assets', 'images', 'logo-black.png'))
      let(:image) { Rack::Test::UploadedFile.new(image_path, 'image/png') }
      let!(:product_without_image) { create(:product) }
      let!(:product_with_image) { create(:product_with_image) }

      sign_in_as_admin!

      it "saves a new image when none is present" do
        xhr :post, :update_product_image, product_id: product_without_image.id, file: image, use_route: :product_images

        expect(response.status).to eq 201
        expect(product_without_image.images.first.id).to eq json_response['id']
      end

      it "updates an existing product image" do
        xhr :post, :update_product_image, product_id: product_with_image.id, file: image, use_route: :product_images

        expect(response.status).to eq 200
        expect(product_with_image.images.first.id).to eq json_response['id']
      end
    end
  end
end
