require_relative 'spec_helper'
require_relative '../../indexer/app/lib/periodic_indexer'

describe "ArchivesSpace Public interface" do

  # Start the dev servers and Selenium
  before(:all) do
    selenium_init($backend_start_fn, $frontend_start_fn)
    state = Object.new.instance_eval do
      @store = {}

      def get_last_mtime(repo_id, record_type)
        @store[[repo_id, record_type]].to_i || 0
      end

      def set_last_mtime(repo_id, record_type, time)
        @store[[repo_id, record_type]] = time
      end

      self
    end

    @indexer = PeriodicIndexer.get_indexer(state)
  end


  before(:all) do
    $driver.navigate.to $frontend
  end


  # Stop selenium, kill the dev servers
  after(:all) do
    report_sleep
    cleanup
  end


  def self.xdescribe(*stuff)
  end

  after(:each) do |group|
    if group.example.exception and ENV['SCREENSHOT_ON_ERROR']
      SeleniumTest.save_screenshot
    end
  end


  describe "Homepage" do

    it "is visible" do
      $driver.find_element_with_text('//h3', /Welcome to ArchivesSpace./)
    end

  end


  describe "Repositories" do

    before(:all) do
      @test_repo_code_1 = "test1#{Time.now.to_i}_#{$$}"
      @test_repo_name_1 = "test repository 1 - #{Time.now}"
      @test_repo_code_2 = "test2#{Time.now.to_i}_#{$$}"
      @test_repo_name_2 = "test repository 2 - #{Time.now}"

      create_test_repo(@test_repo_code_1, @test_repo_name_1)
      create_test_repo(@test_repo_code_2, @test_repo_name_2)

      @indexer.run_index_round
    end


    it "lists all available repositories" do
      $driver.find_element(:link, "Repositories").click
      $driver.find_element_with_text('//a', /#{$test_repo}/)
      $driver.find_element_with_text('//a', /#{@test_repo_code_1}/)
      $driver.find_element_with_text('//a', /#{@test_repo_code_2}/)
    end
    
    it "shows Title (default)  in the sort pulldown" do
      $driver.find_element(:link, "Repositories").click
      $driver.find_element(:xpath, "//a[span = 'Select']").click
      $driver.find_element(:link, "Title" )
      $driver.ensure_no_such_element(:link, "Term") 
    end

  end


  describe "Resources" do

    it "doesn't list an un-published records in the list" do
      $unpublished_uri, unpublished = create_resource(:title => "Unpublished Resource", :publish => false, :id_0 => "unpublished")
      $published_uri, published = create_resource(:title => "Published Resource", :publish => true, :id_0 => "published")

      @indexer.run_index_round

      $driver.find_element(:link, "Collections").click

      $driver.find_element(:link, published)
      $driver.ensure_no_such_element(:link, unpublished)
    end


    it "throws a 404 when trying to access an un-processed resource" do
      $driver.get(URI.join($frontend, $unpublished_uri))

      $driver.find_element_with_text('//h2', /Record Not Found/)
    end


    it "offers pagination when there are more than 10" do
      11.times.each do |i|
        create_resource(:title => "Test Resource #{i}", :publish => true, :id_0 => "id#{i}")
      end

      @indexer.run_index_round

      $driver.find_element(:link, "Collections").click

      $driver.find_element(:css, '.pagination .active a').text.should eq('1')

      $driver.find_element(:link, '2').click
      $driver.find_element(:css, '.pagination .active a').text.should eq('2')

      $driver.find_element(:link, '1').click
      $driver.find_element(:css, '.pagination .active a').text.should eq('1')
      $driver.find_element(:link, '2')
    end

  end

  describe "Digital Objects" do
      before(:all) do
        $published_digital_object_uri, $published_digital_object_title = create_digital_object(
                                    :title => "Published DO",
                                    :publish => true,
                                    :file_versions => [
                                      { :file_uri => "https://archivesssss.xxx", :publish => true}, 
                                      { :file_uri => "http://boo.eu", :publish => false }
                                    ] )
        @indexer.run_index_round
      end
      
      it "displayed the digital object correctly" do
        $driver.get(URI.join($frontend, $published_digital_object_uri))
        $driver.find_element_with_text('//h2', /#{$published_digital_object_title}/)
        $driver.find_element_with_text('//h3', /File Versions/)
        $driver.find_element(:link ,"https://archivesssss.xxx" )
        $driver.ensure_no_such_element( :link, "http://boo.eu") 
      end
  
  end

  describe "Archival Objects" do

    before(:all) do
      $unpublished_resource_uri, unpublished = create_resource(:title => "Unpublished Resource", :publish => false, :id_0 => "unpublished2")
      $published_resource_uri, published = create_resource(:title => "Published Resource", :publish => true, :id_0 => "published2")

      $published_archival_object, $published_archival_object_title = create_archival_object(:title => "Published Top Level AO", :publish => true, :resource => {:ref => $published_resource_uri})
      $unpublished_archival_object, $unpublished_archival_object_title = create_archival_object(:title => "Unpublished Top Level AO", :publish => false, :resource => {:ref => $unpublished_resource_uri})

      @indexer.run_index_round
    end


    it "renders index notes as links when they contain ref_ids of other components" do
      index_link_text = "a sweet link"
      ref_id = JSONModel::HTTP.get_json($published_archival_object)["ref_id"]

      ao_with_note, au_with_note_title = \
      create_archival_object(:title => "AO with an index note",
                             :publish => true,
                             :resource => {:ref => $published_resource_uri},
                             :notes => [{:jsonmodel_type => "note_index",
                                          :publish => true,
                                          :items => [{:jsonmodel_type => "note_index_item",
                                                       :type => "name",
                                                       :value => "something",
                                                       :reference => ref_id,
                                                       :reference_text => index_link_text}]}])
      @indexer.run_index_round

      $driver.get(URI.join($frontend, ao_with_note))
      $driver.find_element(:link, index_link_text).click
      $driver.find_element_with_text('//h2', /#{$published_archival_object_title}/)
    end


    it "is visible in the published resource children list and can be viewed" do
      $driver.get(URI.join($frontend, $published_resource_uri))

      $driver.find_element(:link, $published_archival_object_title)

      $driver.get(URI.join($frontend, $published_archival_object))
      $driver.find_element_with_text('//h2', /#{$published_archival_object_title}/)
    end


    it "doesn't allow viewing of an unpublished archival object" do
      $driver.get(URI.join($frontend, $unpublished_archival_object))
      $driver.find_element_with_text('//h2', /Record Not Found/)
    end

  end


  describe "Agents" do

    before(:all) do
      contact =  { "name" => "Home", "salutation" => "mr", "address_1" => "123 Fake St.",
      "city" => "Springfield"}
      unpublished_agent_uri, $unpublished_agent = create_agent("Unpubished Dude", {"publish" => false})
      published_agent_uri, $published_agent = create_agent("Published Dude",
                                                           {"publish" => true,
                                                            "agent_contacts" => [ contact  ]})

      $published_resource_uri, $published_resource_title = create_resource({
        :title => "Published Resource No.3",
        :publish => true,
        :id_0 => "published3",
        :linked_agents => [
          {:ref => unpublished_agent_uri, :role => 'creator'},
          {:ref => published_agent_uri, :role => 'creator'},
        ]
      })

      @indexer.run_index_round
    end


    it "published are visible in the names search results" do
      $driver.find_element(:link, "Names").click

      $driver.find_element(:link, $published_agent)
      assert(5) {
        $driver.ensure_no_such_element(:link, $unpublished_agent)
      }
    end

    it "linked records show for an agent search" do
      $driver.find_element(:link, $published_agent).click
      $driver.find_element(:link, $published_resource_title)
      $driver.ensure_no_such_element(:xpath, "//*[text()[contains( '1234 Fake St')]]")
      $driver.ensure_no_such_element(:css, '#contacts')
    end

    it "linked record shows published agents in the list" do
      $driver.find_element(:link, $published_resource_title).click
      $driver.find_element(:link, $published_agent)
      $driver.ensure_no_such_element(:link, $unpublished_agent)
    end

    it "shows the Agent Name in the sort pulldown" do
      $driver.find_element(:link, "Names").click
      $driver.find_element(:xpath, "//a[span = 'Select']").click
      $driver.find_element(:link, "Agent Name" )
      $driver.ensure_no_such_element(:link, "Title") 
    end
  end


  describe "Subjects" do
    before(:all) do
      linked_subject_uri, $linked_subject_title = create_subject
      not_linked_subject_uri, $not_linked_subject_title = create_subject

      $published_resource_uri, $published_resource_title = create_resource({
                                                                             :title => "Published Resource No.4",
                                                                             :publish => true,
                                                                             :id_0 => "published4",
                                                                             :subjects => [
                                                                               {:ref => linked_subject_uri}
                                                                             ]
                                                                           })

      @indexer.run_index_round
    end

    it "is visible when it is linked to a published resource" do
      $driver.find_element(:link, "Subjects").click
      $driver.find_element(:link, $linked_subject_title)
    end

    it "is not visible when it not linked to a published resource" do
      $driver.ensure_no_such_element(:link, $not_linked_subject_title)
    end
    
    it "shows the Term  in the sort pulldown" do
      $driver.find_element(:link, "Subjects").click
      $driver.find_element(:xpath, "//a[span = 'Select']").click
      $driver.find_element(:link, "Terms" )
      $driver.ensure_no_such_element(:link, "Title") 
    end
  end

end
